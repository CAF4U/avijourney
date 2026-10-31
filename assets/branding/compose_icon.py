from PIL import Image, ImageDraw, ImageChops
from pathlib import Path
import math, hashlib, json
root=Path(__file__).resolve().parents[2]
source=root/'assets/branding/CAF4U_Symbol_Approved.png'
base=Image.open(source).convert('RGBA')
scale=4
layer=Image.new('RGBA',(base.width*scale,base.height*scale))
d=ImageDraw.Draw(layer)
def box(cx,cy,r):return tuple(round(v*scale) for v in (cx-r,cy-r,cx+r,cy+r))
# Only the two new black pictograms are drawn. The approved raster is untouched.
for r in [82,54,26]: d.ellipse(box(224,525,r),outline='black',width=8*scale)
d.line([(224*scale,525*scale),(281*scale,468*scale)],fill='black',width=9*scale)
for x,y in [(199,484),(265,551)]:d.ellipse(box(x,y,9),fill='black')
# Top-view aircraft silhouette, angled to the right.
points=[(0,-92),(9,-82),(13,-25),(82,20),(82,39),(14,10),(12,67),(36,84),(36,98),(0,83),(-36,98),(-36,84),(-12,67),(-14,10),(-82,39),(-82,20),(-13,-25),(-9,-82)]
a=math.radians(35)
pts=[((729+(x*math.cos(a)-y*math.sin(a))*.88)*scale,(525+(x*math.sin(a)+y*math.cos(a))*.88)*scale) for x,y in points]
d.polygon(pts,fill='black')
layer=layer.resize(base.size,Image.Resampling.LANCZOS)
composed=Image.alpha_composite(base,layer)
# Pixel verification: every pixel outside the added pictogram mask is identical.
mask=layer.getchannel('A').point(lambda a:255 if a else 0)
diff=ImageChops.difference(base,composed)
diff.paste((0,0,0,0),(0,0),mask)
assert all(c.getbbox() is None for c in diff.split())
asset=root/'assets/branding'
composed.save(asset/'CAF4U_Aircraft_Companion_Symbol.png')
light=Image.new('RGBA',base.size,'white');light.alpha_composite(composed)
light.convert('RGB').save(asset/'CAF4U_Aircraft_Companion_App_Icon_Light.png')
for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
 canvas=Image.new('RGB',(size,size),'white')
 mark=light.convert('RGB').copy();mark.thumbnail((round(size*.86),round(size*.86)),Image.Resampling.LANCZOS)
 canvas.paste(mark,((size-mark.width)//2,(size-mark.height)//2))
 canvas.save(root/f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
print(json.dumps({'base_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'base_pixels_preserved_outside_symbols':True,'symbol_bounds':mask.getbbox()}))
