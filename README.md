# Proforma Viewer v1.4.0

The AT200 X01-X24 selector now reads `AT200 Frequency Chart.xlsx` from the same folder as `ProformaViewer.exe`. No network schedule path is used.

## Editing the schedule
Click **Edit frequency file** in the AT200 toolbar, or open `AT200 Frequency Chart.xlsx` beside the executable. Keep `VMI Task` and `X01` to `X24` headers. Any non-empty marker selects that task for that frequency. Save the workbook, then choose the frequency again.

The GitHub publish workflow automatically places the workbook beside the executable. Always download/extract the complete artifact, not only the EXE.
