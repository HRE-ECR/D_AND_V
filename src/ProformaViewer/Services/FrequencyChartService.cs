using ClosedXML.Excel;
namespace ProformaViewer.Services;
public sealed class FrequencyChartService
{
 public static string LocalFilePath=>System.IO.Path.Combine(AppContext.BaseDirectory,"AT200 Frequency Chart.xlsx");
 public IReadOnlySet<string> GetTasks(string frequency)
 {
  var path=LocalFilePath;if(!System.IO.File.Exists(path))throw new System.IO.FileNotFoundException("AT200 Frequency Chart.xlsx is missing from the application folder. Re-extract the complete GitHub build artifact.",path);
  using var wb=new XLWorkbook(path);var ws=wb.Worksheets.First();var used=ws.RangeUsed()??throw new System.IO.InvalidDataException("AT200 Frequency Chart.xlsx is empty.");
  var header=used.RowsUsed().Take(20).FirstOrDefault(r=>r.CellsUsed().Any(c=>c.GetString().Trim().Equals("VMI Task",StringComparison.OrdinalIgnoreCase)))??throw new System.IO.InvalidDataException("The local frequency chart must contain a VMI Task header.");
  var taskCol=header.CellsUsed().First(c=>c.GetString().Trim().Equals("VMI Task",StringComparison.OrdinalIgnoreCase)).Address.ColumnNumber;
  var freqCol=header.CellsUsed().FirstOrDefault(c=>Normalise(c.GetString())==Normalise(frequency))?.Address.ColumnNumber??throw new System.IO.InvalidDataException($"Frequency {frequency} was not found in the local chart.");
  var result=new HashSet<string>(StringComparer.OrdinalIgnoreCase);foreach(var row in ws.Rows(header.RowNumber()+1,used.LastRow().RowNumber())){var task=row.Cell(taskCol).GetString().Trim();var mark=row.Cell(freqCol).GetString().Trim();if(task.Length>0&&mark.Length>0)result.Add(task.ToUpperInvariant());}return result;
 }
 static string Normalise(string v){var s=v.Trim().ToUpperInvariant();return s.StartsWith("X")&&int.TryParse(s[1..],out var n)?$"X{n:00}":s;}
}
