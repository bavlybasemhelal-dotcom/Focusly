"""Bundle the Flutter engine's Latin, Arabic, symbols and emoji fallback fonts."""
from pathlib import Path
import re,urllib.request,concurrent.futures
root=Path(__file__).resolve().parent.parent
engine=Path('C:/dev/flutter/bin/cache/flutter_web_sdk/lib/_engine/engine')
source=(engine/'font_fallback_data.dart').read_text(encoding='utf-8')
files=set(re.findall(r"'((?:notocoloremoji|notosanssymbols2?|notosansarabic)/[^']+\.woff2)'",source))
files.add('roboto/v32/KFOmCnqEu92Fr1Me4GZLCzYlKw.woff2')
output=root/'web'/'fallback-fonts'
def download(relative):
 target=output/relative
 if not target.exists():
  target.parent.mkdir(parents=True,exist_ok=True)
  with urllib.request.urlopen('https://fonts.gstatic.com/s/'+relative,timeout=45) as response:target.write_bytes(response.read())
 return target.stat().st_size
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:sizes=list(pool.map(download,sorted(files)))
license_urls={
 'OFL-NotoColorEmoji.txt':'https://raw.githubusercontent.com/google/fonts/main/ofl/notocoloremoji/OFL.txt',
 'OFL-NotoSansSymbols.txt':'https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssymbols/OFL.txt',
 'OFL-NotoSansArabic.txt':'https://raw.githubusercontent.com/google/fonts/main/ofl/notosansarabic/OFL.txt',
 'LICENSE-Roboto.txt':'https://raw.githubusercontent.com/googlefonts/roboto/main/LICENSE',
}
for name,url in license_urls.items():
 with urllib.request.urlopen(url,timeout=30) as response:(output/name).write_bytes(response.read())
print(f'Bundled {len(files)} fallback fonts, {sum(sizes)} bytes, with redistribution licenses.')
