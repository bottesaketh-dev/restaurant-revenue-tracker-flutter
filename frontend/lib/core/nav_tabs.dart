import 'package:flutter/material.dart';

/// Single source of truth for the app's navigable sidebar tabs.
/// Keys here must match the backend's VALID_TABS (see backend/schemas.py)
/// so that access-control permissions line up between frontend and backend.
class NavTab {
  final String key;
  final String label;
  final IconData icon;
  final String route;

  const NavTab({
    required this.key,
    required this.label,
    required this.icon,
    required this.route,
  });
}

const List<NavTab> kNavTabs = [
  NavTab(key: 'home', label: 'Home', icon: Icons.dashboard_outlined, route: '/home'),
  NavTab(key: 'users', label: 'Users', icon: Icons.group_outlined, route: '/users'),
  NavTab(key: 'pos', label: 'POS Billing', icon: Icons.point_of_sale_outlined, route: '/pos'),
  NavTab(key: 'menu', label: 'Menu Catalog', icon: Icons.restaurant_menu, route: '/menu'),
  NavTab(key: 'staff', label: 'Staff Directory', icon: Icons.people_outline, route: '/staff'),
  NavTab(key: 'groceries', label: 'Groceries', icon: Icons.kitchen, route: '/groceries'),
  NavTab(key: 'kitchen', label: 'Kitchen & Recipes', icon: Icons.inventory_2_outlined, route: '/kitchen'),
  NavTab(key: 'expenses', label: 'General Expenses', icon: Icons.payments, route: '/expenses'),
  NavTab(key: 'reports', label: 'Reports', icon: Icons.analytics_outlined, route: '/reports'),
  NavTab(key: 'ai', label: 'AI Command Center', icon: Icons.auto_awesome, route: '/ai'),
];
