using ClosedXML.Excel;using ProformaViewer.Models;
namespace ProformaViewer.Services;
public sealed class ExcelReaderService
{
 public Task<IReadOnlyList<ProformaEntry>> ReadAsync(string path)=>Task.Run<IReadOnlyList<ProformaEntry>>(()=>Read(path));
 public IReadOnlyList<ProformaEntry> Read(string path)
 {
  if(!System.IO.File.Exists(path))throw new System.IO.FileNotFoundException("Database workbook was not found or the network drive is unavailable.",path);
  using var wb=new XLWorkbook(path);var ws=wb.Worksheets.First();var used=ws.RangeUsed()??throw new System.IO.InvalidDataException("Workbook is empty.");
  var hr=used.RowsUsed().Take(20).FirstOrDefault(r=>{var n=r.CellsUsed().Select(c=>c.GetString().Trim()).Where(x=>x.Length>0).ToHashSet(StringComparer.OrdinalIgnoreCase);return n.Contains("Title")&&n.Contains("Path")&&n.Contains("Page");})??throw new System.IO.InvalidDataException("A header row containing Title, Path and Page was not found.");
  var h=new Dictionary<string,int>(StringComparer.OrdinalIgnoreCase);foreach(var c in hr.CellsUsed()){var n=c.GetString().Trim();if(n.Length>0&&!h.ContainsKey(n))h.Add(n,c.Address.ColumnNumber);}
  var items=new List<ProformaEntry>();foreach(var row in ws.Rows(hr.RowNumber()+1,used.LastRow().RowNumber())){var title=row.Cell(h["Title"]).GetString().Trim();var file=row.Cell(h["Path"]).GetString().Trim();var spec=row.Cell(h["Page"]).GetFormattedString().Trim();if(title.Length==0&&file.Length==0&&spec.Length==0)continue;if(title.Length==0||file.Length==0||spec.Length==0)continue;if(Uri.TryCreate(file,UriKind.Absolute,out var uri)&&uri.IsFile)file=Uri.UnescapeDataString(uri.LocalPath);try{items.Add(new(){Title=title,Path=file,PageSpec=spec,Pages=PageSpecParser.Parse(spec)});}catch(FormatException){}}
  return items.Count>0?items:throw new System.IO.InvalidDataException("The workbook contains no valid proforma records.");
 }
}
