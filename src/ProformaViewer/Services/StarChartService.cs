using ClosedXML.Excel;
namespace ProformaViewer.Services;
public sealed class StarChartService
{
 public IReadOnlySet<string> GetTasks(string filePath,string frequency)
 {
  if(!System.IO.File.Exists(filePath))throw new System.IO.FileNotFoundException("AT200 star chart was not found. Edit Schedules:AT200 in appsettings.json or place 385 Star chart.xlsx in the configured network folder.",filePath);
  using var wb=new XLWorkbook(filePath);var ws=wb.Worksheets.First();var used=ws.RangeUsed()??throw new System.IO.InvalidDataException("The AT200 star chart is empty.");
  var header=used.RowsUsed().Take(20).FirstOrDefault(r=>r.CellsUsed().Any(c=>c.GetString().Trim().Equals("VMI Task",StringComparison.OrdinalIgnoreCase)))??throw new System.IO.InvalidDataException("The star chart must contain a 'VMI Task' header.");
  var taskColumn=header.CellsUsed().First(c=>c.GetString().Trim().Equals("VMI Task",StringComparison.OrdinalIgnoreCase)).Address.ColumnNumber;
  var frequencyCell=header.CellsUsed().FirstOrDefault(c=>Normalise(c.GetString())==Normalise(frequency))??throw new System.IO.InvalidDataException($"Frequency '{frequency}' was not found in the star chart.");
  var result=new HashSet<string>(StringComparer.OrdinalIgnoreCase);var last=used.LastRow().RowNumber();
  foreach(var row in ws.Rows(header.RowNumber()+1,last)){var task=row.Cell(taskColumn).GetString().Trim();var marker=row.Cell(frequencyCell.Address.ColumnNumber).GetString().Trim();if(task.Length>0&&marker.Length>0)result.Add(task.ToUpperInvariant());}
  return result;
 }
 static string Normalise(string value){var s=value.Trim().ToUpperInvariant();if(s.StartsWith("X")&&int.TryParse(s[1..],out var n))return $"X{n:00}";return s;}
}
