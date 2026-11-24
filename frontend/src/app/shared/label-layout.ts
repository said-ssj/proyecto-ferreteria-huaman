export interface LabelFormat {
 id:string; name:string; width:number; height:number; columns:number; rows:number; kind:'roll'|'sheet'|'butterfly';
}
export const LABEL_FORMATS:readonly LabelFormat[] = [
 {id:'100x150',name:'100 × 150 mm · Grande',width:100,height:150,columns:1,rows:1,kind:'roll'},
 {id:'100x100',name:'100 × 100 mm · Cajas',width:100,height:100,columns:1,rows:1,kind:'roll'},
 {id:'100x50',name:'100 × 50 mm · Almacén',width:100,height:50,columns:1,rows:1,kind:'roll'},
 {id:'50x30',name:'50 × 30 mm · Producto',width:50,height:30,columns:1,rows:1,kind:'roll'},
 {id:'50x25',name:'50 × 25 mm · Producto compacto',width:50,height:25,columns:1,rows:1,kind:'roll'},
 {id:'38x25',name:'38 × 25 mm · Pequeña',width:38,height:25,columns:1,rows:1,kind:'roll'},
 {id:'40x30',name:'40 × 30 mm · Pequeña',width:40,height:30,columns:1,rows:1,kind:'roll'},
 {id:'60x40',name:'60 × 40 mm · Mediana',width:60,height:40,columns:1,rows:1,kind:'roll'},
 {id:'32x20',name:'32 × 20 mm · Mini',width:32,height:20,columns:1,rows:1,kind:'roll'},
 {id:'25x15',name:'25 × 15 mm · Mini',width:25,height:15,columns:1,rows:1,kind:'roll'},
 {id:'50x15-lazo',name:'50 × 15 mm · Lazo / mariposa',width:50,height:15,columns:1,rows:1,kind:'butterfly'},
 {id:'a4-24',name:'A4 · 24 etiquetas de 70 × 37 mm',width:70,height:37,columns:3,rows:8,kind:'sheet'},
 {id:'a4-40',name:'A4 · 40 etiquetas de 52,5 × 29,7 mm',width:52.5,height:29.7,columns:4,rows:10,kind:'sheet'},
];
/** Null cells retain alignment on partially used A4 sheets; never create extra labels. */
export function labelPages(quantity:number,format:LabelFormat,start=1):(number|null)[][] {
 const capacity=format.columns*format.rows;
 if(!Number.isInteger(quantity)||quantity<1||quantity>200||!Number.isInteger(start)||start<1||start>capacity)return [];
 const cells:(number|null)[]=Array.from({length:start-1},()=>null);
 cells.push(...Array.from({length:quantity},(_,i)=>i));
 const pages:(number|null)[][]=[];
 for(let i=0;i<cells.length;i+=capacity)pages.push(cells.slice(i,i+capacity));
 return pages;
}
export function barcodeModuleMm(svgWidth:number,format:LabelFormat):number {
 // JsBarcode uses 2 px modules and 22 px quiet zones on either side.
 const available=format.kind==='butterfly'?(format.width-6)/2-2:format.width-4;
 return available/(svgWidth/2);
}
export const LABEL_CSS=`
.label-pages,.label-pages *{box-sizing:border-box}.label-pages{font-family:Arial,sans-serif}
.label-pages{display:grid;gap:16px;width:max-content}
.label-page{display:grid;grid-template-columns:repeat(var(--cols),var(--lw));grid-auto-rows:var(--lh);width:var(--pw);height:var(--ph);align-content:start;background:#fff;overflow:hidden}
.product-label{width:var(--lw);height:var(--lh);padding:2mm;display:flex;flex-direction:column;align-items:stretch;justify-content:center;gap:.6mm;text-align:center;overflow:hidden;color:#111;background:#fff;line-height:1.1;break-inside:avoid}
.product-label>*{flex-shrink:0}
.label-name{font-size:10pt;line-height:1.15;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;overflow-wrap:anywhere}
.label-presentation{font-size:8pt;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.label-price{font-size:11pt;font-weight:bold;white-space:nowrap}
.product-label app-barcode{display:block;min-width:0;background:#fff;color:#111}
.label-pages .product-label svg{display:block;margin:auto;width:100%;height:var(--bh);max-height:none}
.label-pages .product-label .barcode-value{font:8pt Arial,sans-serif;color:#111;text-align:center;overflow-wrap:anywhere;line-height:1.05}
.compact .product-label{gap:.3mm;padding:1mm 2mm}.compact .label-name{font-size:8pt;-webkit-line-clamp:1}.compact .label-presentation{display:none}.compact .label-price{font-size:9pt}.label-pages.compact .barcode-value{font-size:7pt}
.mini .label-name{font-size:6pt}.mini .label-price{font-size:7pt}.label-pages.mini .barcode-value{font-size:5pt}
.butterfly .product-label{padding:1mm;display:grid;grid-template-columns:1fr 6mm 1fr;gap:0;align-items:center}
.butterfly app-barcode{grid-column:1;grid-row:1/3}.butterfly .label-name{grid-column:3;grid-row:1;font-size:6pt;-webkit-line-clamp:2}.butterfly .label-price{grid-column:3;grid-row:2;font-size:7pt}.butterfly .label-presentation{display:none}.label-pages.butterfly .barcode-value{font-size:5pt}
`;
export const LABEL_PRINT_CSS=`*{box-sizing:border-box}body{margin:0;background:#fff;color:#111;font-family:Arial,sans-serif}`+LABEL_CSS+`
@media print{html,body{margin:0!important;padding:0!important}.label-pages{display:block}.label-page{break-after:page;page-break-after:always}.label-page:last-child{break-after:auto;page-break-after:auto}.product-label{print-color-adjust:exact;-webkit-print-color-adjust:exact}}
`;
