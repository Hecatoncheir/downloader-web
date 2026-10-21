from PIL import Image, ImageDraw
from pathlib import Path
root=Path(__file__).resolve().parents[1]
def bezier(points,n=40):
    result=[]
    for i in range(n+1):
        t=i/n; u=1-t
        if len(points)==4: result.append(tuple(u**3*points[0][j]+3*u*u*t*points[1][j]+3*u*t*t*points[2][j]+t**3*points[3][j] for j in (0,1)))
        else: result.append(tuple(u*u*points[0][j]+2*u*t*points[1][j]+t*t*points[2][j] for j in (0,1)))
    return result
blob=[]
for segment in [[(18,5),(4,7),(5,28),(6,43)],[(6,43),(7,59),(16,63),(33,59)],[(33,59),(52,55),(62,47),(58,29)],[(58,29),(55,12),(38,1),(18,5)]]: blob+=bezier(segment)
arrow=bezier([(31,17),(30,23),(29,32),(30,41)])
chevron=bezier([(20,32),(24,39),(30,44)])+bezier([(30,44),(37,39),(43,30)])
def render(size,maskable=False):
    scale=4; factor=size*scale/64; inset=8 if maskable else 0
    def xy(points): return [((inset+x*(64-2*inset)/64)*factor,(inset+y*(64-2*inset)/64)*factor) for x,y in points]
    image=Image.new('RGB',(size*scale,size*scale),'#191410'); draw=ImageDraw.Draw(image)
    draw.polygon(xy(blob),fill='#d9d4bd')
    width=7*factor*(64-2*inset)/64
    for points in [arrow,chevron]:
        coords=xy(points); draw.line(coords,fill='#191410',width=round(width),joint='curve')
        for x,y in (coords[0],coords[-1]): draw.ellipse((x-width/2,y-width/2,x+width/2,y+width/2),fill='#191410')
    return image.resize((size,size),Image.Resampling.LANCZOS)
render(32).save(root/'web/favicon.png')
for size in (192,512):
    render(size).save(root/f'web/icons/Icon-{size}.png')
    render(size,True).save(root/f'web/icons/Icon-maskable-{size}.png')
render(512).save(root/'assets/brand/mark.png')
