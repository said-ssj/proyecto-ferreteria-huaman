// Dedicated print rules: no modal height limit, clipped table or theme-dependent colors.
export const DISPATCH_PRINT_CSS=`
@page{size:A4;margin:12mm}*{box-sizing:border-box}body{margin:0;color:#111;background:#fff;font:11pt Arial,sans-serif;line-height:1.35}
.preparation-sheet{width:100%;max-height:none;overflow:visible;border:0}
.sheet-header{border-bottom:2px solid #444;padding-bottom:4mm}.sheet-title{font-size:16pt;margin:0 0 2mm}
.sheet-meta-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:3mm;padding:4mm 0}
.meta-item{display:flex;flex-direction:column;overflow-wrap:anywhere}.meta-label{font-weight:bold}.sheet-obs-callout{padding:3mm 0;overflow-wrap:anywhere}
.sheet-table-wrap{overflow:visible}.sheet-table{width:100%;border-collapse:collapse;table-layout:fixed}
.sheet-table thead{display:table-header-group}.sheet-table tr{break-inside:avoid}.sheet-table th,.sheet-table td{padding:2mm;border-bottom:1px solid #999;text-align:left;overflow-wrap:anywhere}
.sheet-table th{background:#eee}.unit-sub{display:block}.sheet-footer{margin-top:8mm;break-inside:avoid}
.sheet-signatures{display:flex;justify-content:space-between;gap:10mm;padding-top:8mm}.signature-box{width:45%;font-size:10pt}.signature-line{border-top:1px solid #111;margin-bottom:2mm}
.print-hidden{display:none!important}app-icon{display:none}.sheet-header-actions{display:none}
`;
