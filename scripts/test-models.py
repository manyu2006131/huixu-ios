from pathlib import Path
import subprocess,tempfile
r=Path(__file__).resolve().parent.parent
s=(r/'Huixu/HuixuApp.swift').read_text()
models=s[s.index('struct EditLayer:'):s.index('// MARK: Rendering.')]
tests=r'''
func check(_ v: @autoclosure () -> Bool, _ message:String) { if !v() { fatalError(message) } }
var doc = ArtDocument()
let l = EditLayer(name:"中文图层",text:"Hello 魔法",x:123,y:456,rotation:0.5)
doc.layers=[l];try doc.validate()
let bytes=try JSONEncoder().encode(doc)
let restored=try JSONDecoder().decode(ArtDocument.self,from:bytes)
check(restored==doc,"document roundtrip lost transforms or text")
var bad=doc;bad.width=99999
do {try bad.validate();fatalError("oversize canvas accepted")}catch{}
bad=doc;bad.layers.append(l)
do {try bad.validate();fatalError("duplicate layer UUID accepted")}catch{}
bad=doc;bad.layers[0].scale=0
do {try bad.validate();fatalError("zero scale accepted")}catch{}
bad=doc;bad.layers[0].opacity=2
do {try bad.validate();fatalError("invalid opacity accepted")}catch{}
var clearing=doc;clearing.drawing=Data([1,2,3]);clearing.drawing=Data()
check(clearing.layers==doc.layers,"clearing ink erased image/text layers")
print("PASS: document roundtrip, transforms, Unicode, invalid dimensions, duplicate UUID, invalid scale and opacity, ink isolation")
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'main.swift';p.write_text('import Foundation\n'+models+tests)
 subprocess.run(['swift',str(p)],check=True)
