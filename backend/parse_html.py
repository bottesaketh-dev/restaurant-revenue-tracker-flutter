import html.parser
class HTMLFilter(html.parser.HTMLParser):
    text = ''
    def handle_data(self, data):
        self.text += data

with open('../Hyderabad Restaurant Database Population.html', encoding='utf-8') as f:
    html_content = f.read()

f = HTMLFilter()
f.feed(html_content)

with open('parsed.txt', 'w', encoding='utf-8') as out:
    out.write(f.text)
