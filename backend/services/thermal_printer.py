import ctypes
from ctypes import wintypes
import logging
from datetime import datetime
from typing import List, Dict, Any, Optional

logger = logging.getLogger("thermal_printer")
logger.setLevel(logging.INFO)

class DOC_INFO_1(ctypes.Structure):
    _fields_ = [
        ("pDocName", wintypes.LPCWSTR),
        ("pOutputFile", wintypes.LPCWSTR),
        ("pDatatype", wintypes.LPCWSTR),
    ]

# ESC/POS Constants
ESC = b"\x1b"
GS = b"\x1d"

INIT = ESC + b"@"
ALIGN_LEFT = ESC + b"a\x00"
ALIGN_CENTER = ESC + b"a\x01"
ALIGN_RIGHT = ESC + b"a\x02"

BOLD_ON = ESC + b"E\x01"
BOLD_OFF = ESC + b"E\x00"

DOUBLE_HEIGHT_ON = ESC + b"!\x10"
DOUBLE_SIZE_ON = GS + b"!\x11"
NORMAL_SIZE = GS + b"!\x00" + ESC + b"!\x00"

LINE_FEED = b"\n"
CUT_PAPER = GS + b"V\x41\x03"  # Feed 3 lines and full cut

DEFAULT_PRINTER_NAME = "Retsol_POS_80"
PAPER_WIDTH_CHARS = 48  # Standard for 80mm thermal receipt


def _format_two_column(left: str, right: str, width: int = PAPER_WIDTH_CHARS) -> str:
    """Format a two-column row with left and right aligned text."""
    spaces = max(1, width - len(left) - len(right))
    return left + (" " * spaces) + right + "\n"


def _format_item_row(name: str, qty: int, price: float, total: float, width: int = PAPER_WIDTH_CHARS) -> str:
    """Format an order item row: Name (24), Qty (4), Price (8), Total (9) = 48 chars."""
    short_name = name[:23]
    price_str = f"{price:.2f}"
    total_str = f"{total:.2f}"
    return f"{short_name:<24} {qty:>4} {price_str:>8} {total_str:>9}\n"


def send_raw_to_printer(raw_data: bytes, printer_name: str = DEFAULT_PRINTER_NAME) -> tuple[bool, str]:
    """Send raw bytes directly to a Windows printer queue using winspool.drv."""
    try:
        winspool = ctypes.windll.LoadLibrary("winspool.drv")
        h_printer = wintypes.HANDLE()

        if not winspool.OpenPrinterW(printer_name, ctypes.byref(h_printer), None):
            error_code = ctypes.GetLastError()
            return False, f"Failed to open printer '{printer_name}' (Error: {error_code})"

        try:
            doc_info = DOC_INFO_1("IOR 360 Thermal Print", None, "RAW")
            job_id = winspool.StartDocPrinterW(h_printer, 1, ctypes.byref(doc_info))
            if not job_id:
                return False, f"StartDocPrinter failed (Error: {ctypes.GetLastError()})"

            try:
                winspool.StartPagePrinter(h_printer)
                written = wintypes.DWORD()
                data_bytes = bytes(raw_data) if isinstance(raw_data, (bytes, bytearray)) else str(raw_data).encode("utf-8")
                success = winspool.WritePrinter(h_printer, data_bytes, len(data_bytes), ctypes.byref(written))
                winspool.EndPagePrinter(h_printer)
                winspool.EndDocPrinter(h_printer)

                if success:
                    return True, f"Printed successfully ({written.value} bytes sent)"
                else:
                    return False, f"WritePrinter failed (Error: {ctypes.GetLastError()})"
            except Exception as e:
                winspool.EndDocPrinter(h_printer)
                raise e
        finally:
            winspool.ClosePrinter(h_printer)

    except Exception as e:
        logger.error(f"Printing error: {e}")
        return False, str(e)


def generate_bill_receipt_bytes(
    restaurant_name: str,
    branch_name: str,
    branch_phone: str,
    bill_id: str,
    table_id: str,
    order_type: str,
    cashier_name: str,
    date_str: str,
    time_str: str,
    items: List[Dict[str, Any]],
    subtotal: float,
    tax_amount: float,
    discount_amount: float,
    tip_amount: float,
    grand_total: float,
    payment_mode: str,
) -> bytes:
    """Generate raw ESC/POS bytes for a customer bill receipt (80mm)."""
    buf = bytearray()

    # 1. Initialize
    buf += INIT

    # 2. Header
    buf += ALIGN_CENTER + BOLD_ON + DOUBLE_SIZE_ON
    buf += f"{restaurant_name.upper()}\n".encode("utf-8")
    buf += NORMAL_SIZE + BOLD_OFF

    if branch_name:
        buf += f"{branch_name}\n".encode("utf-8")
    if branch_phone:
        buf += f"Phone: {branch_phone}\n".encode("utf-8")
    buf += (b"=" * PAPER_WIDTH_CHARS) + LINE_FEED

    # 3. Bill Meta Info
    buf += ALIGN_LEFT
    buf += _format_two_column(f"Date: {date_str} {time_str}", f"Bill: #{bill_id[-8:]}").encode("utf-8")
    table_label = "TAKEAWAY" if table_id == "TAKEAWAY" else f"Table: {table_id}"
    buf += _format_two_column(table_label, f"Cashier: {cashier_name}").encode("utf-8")
    buf += (b"-" * PAPER_WIDTH_CHARS) + LINE_FEED

    # 4. Item Headers
    buf += f"{'ITEM':<24} {'QTY':>4} {'PRICE':>8} {'TOTAL':>9}\n".encode("utf-8")
    buf += (b"-" * PAPER_WIDTH_CHARS) + LINE_FEED

    # 5. Items List
    for item in items:
        name = item.get("name", "Unknown Item")
        qty = int(item.get("quantity", 1))
        price = float(item.get("price", 0.0))
        total = float(item.get("total_price", qty * price))
        buf += _format_item_row(name, qty, price, total).encode("utf-8")

    buf += (b"-" * PAPER_WIDTH_CHARS) + LINE_FEED

    # 6. Totals & Tax
    buf += _format_two_column("Subtotal:", f"{subtotal:.2f}").encode("utf-8")
    if tax_amount > 0:
        buf += _format_two_column("GST (5%):", f"{tax_amount:.2f}").encode("utf-8")
    if discount_amount > 0:
        buf += _format_two_column("Discount:", f"-{discount_amount:.2f}").encode("utf-8")
    if tip_amount > 0:
        buf += _format_two_column("Tip:", f"{tip_amount:.2f}").encode("utf-8")

    buf += (b"=" * PAPER_WIDTH_CHARS) + LINE_FEED

    # 7. Grand Total (Double size + Bold)
    buf += BOLD_ON + DOUBLE_HEIGHT_ON
    buf += _format_two_column("GRAND TOTAL:", f"Rs. {grand_total:.2f}").encode("utf-8")
    buf += NORMAL_SIZE + BOLD_OFF

    buf += _format_two_column("Payment Mode:", f"{payment_mode.upper()}").encode("utf-8")
    buf += (b"=" * PAPER_WIDTH_CHARS) + LINE_FEED

    # 8. Footer
    buf += ALIGN_CENTER
    buf += b"Thank You for Dining With Us!\n"
    buf += b"Please Visit Again\n"
    buf += LINE_FEED * 4

    # 9. Cut Paper
    buf += CUT_PAPER

    return bytes(buf)


def generate_kot_receipt_bytes(
    table_id: str,
    order_type: str,
    time_str: str,
    items: List[Dict[str, Any]],
) -> bytes:
    """Generate raw ESC/POS bytes for a Kitchen Order Ticket (KOT)."""
    buf = bytearray()

    buf += INIT
    buf += ALIGN_CENTER + BOLD_ON + DOUBLE_SIZE_ON
    buf += b"*** KITCHEN ORDER TICKET ***\n"
    buf += NORMAL_SIZE + BOLD_OFF
    buf += (b"=" * PAPER_WIDTH_CHARS) + LINE_FEED

    buf += ALIGN_LEFT + BOLD_ON
    table_label = "TAKEAWAY ORDER" if table_id == "TAKEAWAY" else f"TABLE: {table_id}"
    buf += _format_two_column(table_label, f"Time: {time_str}").encode("utf-8")
    buf += BOLD_OFF
    buf += (b"-" * PAPER_WIDTH_CHARS) + LINE_FEED

    # Item Headers
    buf += f"{'ITEM NAME':<38} {'QTY':>8}\n".encode("utf-8")
    buf += (b"-" * PAPER_WIDTH_CHARS) + LINE_FEED

    # Items
    buf += BOLD_ON + DOUBLE_HEIGHT_ON
    for item in items:
        name = item.get("name", "Unknown Item")[:30]
        qty = int(item.get("quantity", 1))
        buf += f"{name:<30} {f'x {qty}':>8}\n".encode("utf-8")
        notes = item.get("notes")
        if notes:
            buf += NORMAL_SIZE + f"  * Note: {notes}\n".encode("utf-8") + BOLD_ON + DOUBLE_HEIGHT_ON

    buf += NORMAL_SIZE + BOLD_OFF
    buf += (b"=" * PAPER_WIDTH_CHARS) + LINE_FEED
    buf += LINE_FEED * 4
    buf += CUT_PAPER

    return bytes(buf)
