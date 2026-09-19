using System.Collections.ObjectModel;using System.Diagnostics;using System.Windows;using System.Windows.Controls;using System.Windows.Input;using System.Windows.Media;using Microsoft.Extensions.Configuration;using Microsoft.Win32;using ProformaViewer.Models;using ProformaViewer.Services;
namespace ProformaViewer;
public partial class MainWindow:Window
{
 readonly ExcelReaderService excel=new();readonly StarChartService chart=new();readonly PdfExportService pdf=new();readonly ObservableCollection<ProformaEntry> entries=new();readonly IConfiguration config;string? databasePath;string? fleet;
 public MainWindow(){InitializeComponent();WindowState=WindowState.Maximized;config=new ConfigurationBuilder().SetBasePath(AppContext.BaseDirectory).AddJsonFile("appsettings.json",false,true).Build();ItemsList.ItemsSource=entries;for(var i=1;i<=24;i++)FrequencyBox.Items.Add(new ComboBoxItem{Content=$"X{i:00}"});SourceInitialized+=(_,_)=>WindowState=WindowState.Maximized;}
 async void Database_Click(object sender,RoutedEventArgs e){fleet=(string)((FrameworkElement)sender).Tag;var path=config[$"Databases:{fleet}"]??"";SetBusy(true,$"Loading {fleet}...");try{var rows=await excel.ReadAsync(path);entries.Clear();foreach(var row in rows)entries.Add(row);databasePath=path;ShowList(fleet);StatusText.Text=$"{rows.Count} items loaded";}catch(Exception ex){MessageBox.Show(ex.Message,"Unable to load database",MessageBoxButton.OK,MessageBoxImage.Error);StatusText.Text="Database unavailable";}finally{SetBusy(false);}}
 void ShowList(string f){HomePanel.Visibility=Visibility.Collapsed;ItemsList.Visibility=Visibility.Visible;SelectAllButton.Visibility=ClearButton.Visibility=ExportButton.Visibility=FleetButton.Visibility=FolderButton.Visibility=Visibility.Visible;FrequencyBox.Visibility=f=="AT200"?Visibility.Visible:Visibility.Collapsed;FrequencyBox.SelectedIndex=0;SubTitle.Text=$"{f} | select one or more proformas";InstructionText.Text="Click anywhere on a tile to select or deselect it";}
 async void FrequencyBox_SelectionChanged(object sender,SelectionChangedEventArgs e){if(fleet!="AT200"||FrequencyBox.SelectedIndex<=0)return;var selected=(FrequencyBox.SelectedItem as ComboBoxItem)?.Content?.ToString();if(string.IsNullOrWhiteSpace(selected))return;var path=config["Schedules:AT200"]??"";SetBusy(true,$"Loading {selected} schedule...");try{var tasks=await Task.Run(()=>chart.GetTasks(path,selected));ItemsList.UnselectAll();foreach(var item in entries.Where(x=>tasks.Contains(x.TaskCode)))ItemsList.SelectedItems.Add(item);var unmatched=tasks.Where(t=>entries.All(x=>!x.TaskCode.Equals(t,StringComparison.OrdinalIgnoreCase))).ToList();StatusText.Text=$"{ItemsList.SelectedItems.Count} proformas selected for {selected}"+(unmatched.Count>0?$" | Not in database: {string.Join(", ",unmatched)}":"");}catch(Exception ex){MessageBox.Show(ex.Message,"Unable to load AT200 frequency",MessageBoxButton.OK,MessageBoxImage.Error);}finally{SetBusy(false);}}
 void ItemsList_PreviewMouseLeftButtonDown(object sender,MouseButtonEventArgs e){var item=FindParent<ListBoxItem>(e.OriginalSource as DependencyObject);if(item==null)return;item.IsSelected=!item.IsSelected;e.Handled=true;}
 static T? FindParent<T>(DependencyObject? child) where T:DependencyObject{while(child!=null){if(child is T found)return found;child=VisualTreeHelper.GetParent(child);}return null;}
 void Home_Click(object s,RoutedEventArgs e){ItemsList.UnselectAll();ItemsList.Visibility=SelectAllButton.Visibility=ClearButton.Visibility=ExportButton.Visibility=FleetButton.Visibility=FolderButton.Visibility=FrequencyBox.Visibility=Visibility.Collapsed;HomePanel.Visibility=Visibility.Visible;SubTitle.Text="Choose a fleet database";InstructionText.Text="Select a fleet to begin";StatusText.Text="Ready";databasePath=fleet=null;}
 void Folder_Click(object s,RoutedEventArgs e){if(string.IsNullOrWhiteSpace(databasePath))return;var folder=System.IO.Path.GetDirectoryName(databasePath);if(string.IsNullOrWhiteSpace(folder)||!System.IO.Directory.Exists(folder)){MessageBox.Show("The database folder is unavailable.","Folder unavailable",MessageBoxButton.OK,MessageBoxImage.Warning);return;}Process.Start(new ProcessStartInfo("explorer.exe",$"\"{folder}\""){UseShellExecute=true});}
 void SelectAll_Click(object s,RoutedEventArgs e)=>ItemsList.SelectAll();void Clear_Click(object s,RoutedEventArgs e){FrequencyBox.SelectedIndex=0;ItemsList.UnselectAll();}void ItemsList_SelectionChanged(object s,SelectionChangedEventArgs e)=>UpdateCount();void UpdateCount(){var n=ItemsList.SelectedItems.Count;ExportButton.IsEnabled=n>0;StatusText.Text=$"{n} selected";}
 async void Export_Click(object s,RoutedEventArgs e){var selected=ItemsList.SelectedItems.Cast<ProformaEntry>().ToList();var d=new SaveFileDialog{Filter="PDF files (*.pdf)|*.pdf",FileName=$"Combined Proformas {DateTime.Now:yyyy-MM-dd HHmm}.pdf",DefaultExt=".pdf"};if(d.ShowDialog()!=true)return;SetBusy(true,"Exporting pages...");Progress.Visibility=Visibility.Visible;try
  {
   var result=await pdf.ExportAsync(selected,d.FileName,new Progress<int>(v=>Progress.Value=v));
   StatusText.Text=$"Export complete: {result.PageCount} pages";
   var warningText=result.Errors.Count>0
    ? $"\n\nWarnings:\n{string.Join("\n",result.Errors)}"
    : string.Empty;
   var prompt=$"Created {result.PageCount}-page PDF.{warningText}\n\nOpen the combined PDF now?";
   var answer=MessageBox.Show(
    prompt,
    "Export complete",
    MessageBoxButton.YesNo,
    result.Errors.Count>0?MessageBoxImage.Warning:MessageBoxImage.Information,
    MessageBoxResult.Yes);
   if(answer==MessageBoxResult.Yes)
   {
    Process.Start(new ProcessStartInfo
    {
     FileName=d.FileName,
     UseShellExecute=true
    });
   }
  }
  catch(Exception ex){MessageBox.Show(ex.Message,"Export failed",MessageBoxButton.OK,MessageBoxImage.Error);}finally{Progress.Visibility=Visibility.Collapsed;SetBusy(false);UpdateCount();}}
 void SetBusy(bool busy,string? text=null){ExportButton.IsEnabled=!busy&&ItemsList.SelectedItems.Count>0;if(text!=null)StatusText.Text=text;Mouse.OverrideCursor=busy?Cursors.Wait:null;}
}
