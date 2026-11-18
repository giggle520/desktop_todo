Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$created = $false
$mutex = [Threading.Mutex]::new($true, 'Local\DesktopTodo', [ref]$created)
if (!$created) {
    if ($args -notcontains '-Tray') {
        try {
            $existing = [Threading.EventWaitHandle]::OpenExisting('Local\DesktopTodoOpen')
            try { [void]$existing.Set() } finally { $existing.Dispose() }
        } catch [Threading.WaitHandleCannotBeOpenedException] {}
    }
    $mutex.Dispose()
    return
}
$openSignal = [Threading.EventWaitHandle]::new($false, 'AutoReset', 'Local\DesktopTodoOpen')
[Windows.Forms.Application]::EnableVisualStyles()
$dir = Join-Path $env:LOCALAPPDATA 'DesktopTodo'
[IO.Directory]::CreateDirectory($dir) | Out-Null
$file = Join-Path $dir 'tasks.json'
$form = [Windows.Forms.Form]::new()
$form.Text = '待办事项'
$form.Size = [Drawing.Size]::new(500, 650)
$form.MinimumSize = [Drawing.Size]::new(390, 340)
$form.StartPosition = 'CenterScreen'
$form.ShowInTaskbar = $false
$form.Font = [Drawing.Font]::new('Microsoft YaHei UI', 11)
$form.BackColor = [Drawing.Color]::FromArgb(246, 248, 253)
$layout = [Windows.Forms.TableLayoutPanel]::new()
$layout.Dock = 'Fill'
$layout.Padding = [Windows.Forms.Padding]::new(20)
$layout.ColumnCount = 2
$layout.RowCount = 4
[void]$layout.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent', 100))
[void]$layout.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Absolute', 88))
$layout.RowStyles.Clear()
[void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute', 76))
[void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute', 42))
[void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent', 100))
[void]$layout.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute', 46))


$form.Controls.Add($layout)
$header = [Windows.Forms.Panel]::new()
$header.Dock = 'Fill'
$title = [Windows.Forms.Label]::new()
$title.Text = '待办事项'
$title.Font = [Drawing.Font]::new($form.Font.FontFamily, 19, [Drawing.FontStyle]::Bold)
$title.ForeColor = [Drawing.Color]::FromArgb(26, 37, 62)
$title.AutoSize = $true
$progress = [Windows.Forms.Label]::new()
$progress.Location = [Drawing.Point]::new(3, 41)
$progress.ForeColor = [Drawing.Color]::FromArgb(85, 99, 128)
$progress.AutoSize = $true
$header.Controls.Add($title)
$header.Controls.Add($progress)
$layout.Controls.Add($header, 0, 0)
$layout.SetColumnSpan($header, 2)
$inputBox = [Windows.Forms.TextBox]::new()
$inputBox.Dock = 'Fill'
$inputBox.AutoSize = $false
$inputBox.Margin = [Windows.Forms.Padding]::new(3, 3, 3, 3)
$inputBox.MaxLength = 300
$inputBox.AccessibleName = '新待办事项'
$add = [Windows.Forms.Button]::new()
$add.Text = '添加'
$add.Dock = 'Fill'
function New-TaskGrid {
    $list = [Windows.Forms.DataGridView]::new()
    $list.Dock = 'Fill'
    $list.ReadOnly = $true
    $list.AllowUserToAddRows = $false
    $list.AllowUserToDeleteRows = $false
    $list.AllowUserToResizeRows = $false
    $list.RowHeadersVisible = $false
    $list.ColumnHeadersVisible = $false
    $list.SelectionMode = 'FullRowSelect'
    $list.MultiSelect = $false
    $list.BackgroundColor = [Drawing.Color]::White
    $list.RowTemplate.Height = 38
    $list.BorderStyle = 'None'
    $list.CellBorderStyle = 'SingleHorizontal'
    $list.GridColor = [Drawing.Color]::FromArgb(235, 239, 249)
    $list.DefaultCellStyle.SelectionBackColor = [Drawing.Color]::FromArgb(227, 235, 255)
    $list.DefaultCellStyle.SelectionForeColor = [Drawing.Color]::FromArgb(25, 39, 74)
    $check = [Windows.Forms.DataGridViewCheckBoxColumn]::new()
    $check.Width = 36
    $check.HeaderText = '完成'
    $taskText = [Windows.Forms.DataGridViewTextBoxColumn]::new()
    $taskText.HeaderText = '待办事项'
    $taskText.AutoSizeMode = 'Fill'
    [void]$list.Columns.Add($check)
    [void]$list.Columns.Add($taskText)
    return $list
}
$list = New-TaskGrid
$script:activeGrid = $list
$doneFont = [Drawing.Font]::new($form.Font, [Drawing.FontStyle]::Strikeout)
$edit = [Windows.Forms.Button]::new()
$edit.Text = '编辑所选'
$delete = [Windows.Forms.Button]::new()
$delete.Text = '删除所选'
$actions = [Windows.Forms.FlowLayoutPanel]::new()
$actions.Dock = 'Fill'
$actions.FlowDirection = 'RightToLeft'
foreach ($button in $add, $edit, $delete) {
    $button.FlatStyle = 'Flat'
    $button.FlatAppearance.BorderSize = 0
    $button.Height = 34
    $button.Width = 90
    $button.BackColor = [Drawing.Color]::FromArgb(231, 237, 251)
    $button.ForeColor = [Drawing.Color]::FromArgb(37, 63, 136)
}
$add.BackColor = [Drawing.Color]::FromArgb(62, 92, 216)
$add.ForeColor = [Drawing.Color]::White
$actions.Controls.Add($delete)
$actions.Controls.Add($edit)
$layout.Controls.Add($inputBox, 0, 1)
$layout.Controls.Add($add, 1, 1)
$layout.Controls.Add($list, 0, 2)
$layout.SetColumnSpan($list, 2)
$layout.Controls.Add($actions, 0, 3)
$layout.SetColumnSpan($actions, 2)
$form.AcceptButton = $add
$script:readOnly = $false
$script:tasks = @()
$script:showCompleted = $false
function Read-Tasks([string]$path) {
    if (![IO.File]::Exists($path)) { return }
    $json = [IO.File]::ReadAllText($path)
    if (!$json.TrimStart().StartsWith('[')) { throw 'Invalid task file' }
    foreach ($item in (ConvertFrom-Json -InputObject $json -ErrorAction Stop)) {
        if ($item -is [string]) { [pscustomobject]@{text=$item; done=$false} }
        elseif ($null -ne $item -and $item.text -is [string] -and $item.done -is [bool]) {
            [pscustomobject]@{text=$item.text; done=$item.done}
        } elseif ($null -ne $item) { throw 'Invalid task file' }
    }
}
try { $script:tasks = @(Read-Tasks $file) }
catch {
    $script:readOnly = $true
    $add.Enabled = $false
    $inputBox.ReadOnly = $true
    [void][Windows.Forms.MessageBox]::Show("无法读取待办文件，原文件已保留：$file", '待办事项')
}
function Save-Tasks([object[]]$items) {
    $temp = "$file.tmp"
    try {
        [IO.File]::WriteAllText($temp, (ConvertTo-Json -InputObject @($items) -Compress), [Text.Encoding]::UTF8)
        if ([IO.File]::Exists($file)) { [IO.File]::Replace($temp, $file, "$file.bak") }
        else { [IO.File]::Move($temp, $file) }
        return $true
    } catch {
        [void][Windows.Forms.MessageBox]::Show('保存失败，请检查本机磁盘。', '待办事项')
        return $false
    }
}
function Render-Tasks([int]$selected = -1) {
    $completed = @($script:tasks | Where-Object { $_.done }).Count
    $progress.Text = "已完成 $completed / $($script:tasks.Count) 项"
    $list.Rows.Clear()
    foreach ($done in $false,$true) {
        if ($done) {
            if ($list.Rows.Count -gt 0) {
                $spacer = $list.Rows[$list.Rows.Add()]
                $spacer.Height = $list.RowTemplate.Height
                $spacer.Tag = 'completed-spacer'

                $spacer.DividerHeight = 0
                $spacer.DefaultCellStyle.BackColor = $form.BackColor
                $spacer.DefaultCellStyle.SelectionBackColor = $form.BackColor
            }
            $groupRow = $list.Rows[$list.Rows.Add()]
            $groupRow.Tag = 'completed-group'
            $groupRow.Cells[1].Value = "已完成 ($completed)"
            $groupRow.DefaultCellStyle.BackColor = [Drawing.Color]::FromArgb(235, 240, 252)
            if (!$script:showCompleted) { continue }
        }
        for ($i=0; $i -lt $script:tasks.Count; $i++) {
            $item = $script:tasks[$i]
            if ($item.done -ne $done) { continue }
            $row = $list.Rows[$list.Rows.Add()]
            $row.Tag = $i
            $row.Cells[0].Value = $item.done
            $row.Cells[1].Value = $item.text
            if ($done) {
                $row.Cells[1].Style.Font = $doneFont
                $row.Cells[1].Style.ForeColor = [Drawing.Color]::DimGray
            }
            if ($i -eq $selected) { $list.CurrentCell = $row.Cells[1] }
        }
    }
}
function Update-Task([int]$index, [string]$text, [bool]$done) {
    $next = @($script:tasks.Clone())
    $next[$index] = [pscustomobject]@{text=$text; done=$done}
    if (Save-Tasks $next) { $script:tasks = $next; Render-Tasks $index }
}
$add.Add_Click({
    $value = $inputBox.Text.Trim()
    if (!$value -or $script:readOnly) { return }
    $next = @($script:tasks) + @([pscustomobject]@{text=$value; done=$false})
    if (Save-Tasks $next) {
        $script:tasks = $next
        Render-Tasks ($next.Count - 1)
        if ($list.Rows.Count) { $list.FirstDisplayedScrollingRowIndex = $list.CurrentRow.Index }
        $inputBox.Clear()
        [void]$inputBox.Focus()
    }
})
$delete.Add_Click({
    if (!$script:activeGrid.CurrentRow -or $script:activeGrid.CurrentRow.Tag -isnot [int] -or $script:readOnly) { return }
    $index = $script:activeGrid.CurrentRow.Tag
    $next = @(for ($i=0; $i -lt $script:tasks.Count; $i++) { if ($i -ne $index) { $script:tasks[$i] } })
    if (Save-Tasks $next) { $script:tasks = $next; Render-Tasks }
})
function Show-TaskEditor([string]$text) {
    $dialog = [Windows.Forms.Form]::new()
    try {
        $dialog.Text = '编辑待办'
        $dialog.ClientSize = [Drawing.Size]::new(420, 155)
        $dialog.FormBorderStyle = 'FixedDialog'
        $dialog.StartPosition = 'CenterParent'
        $dialog.ShowInTaskbar = $false
        $dialog.MaximizeBox = $false
        $dialog.MinimizeBox = $false
        $dialog.Font = $form.Font
        $dialog.BackColor = $form.BackColor
        $label = [Windows.Forms.Label]::new()
        $label.Text = '待办内容'
        $label.AutoSize = $true
        $label.Location = [Drawing.Point]::new(20, 20)
        $label.ForeColor = [Drawing.Color]::FromArgb(26, 37, 62)
        $box = [Windows.Forms.TextBox]::new()
        $box.Font = $dialog.Font
        $box.Width = 380
        $box.AutoSize = $true
        $box.BorderStyle = 'FixedSingle'
        $box.Location = [Drawing.Point]::new(20, (49 + [int][Math]::Floor((34 - $box.PreferredHeight) / 2)))
        $box.MaxLength = 300
        $box.AccessibleName = '待办内容'
        $box.Text = $text
        $save = [Windows.Forms.Button]::new()
        $save.Text = '保存'
        $save.DialogResult = 'OK'
        $save.Location = [Drawing.Point]::new(312, 103)
        $save.BackColor = $add.BackColor
        $save.ForeColor = [Drawing.Color]::White
        $save.Enabled = [bool]$box.Text.Trim()
        $cancel = [Windows.Forms.Button]::new()
        $cancel.Text = '取消'
        $cancel.DialogResult = 'Cancel'
        $cancel.Location = [Drawing.Point]::new(216, 103)
        $cancel.BackColor = [Drawing.Color]::FromArgb(231, 237, 251)
        $cancel.ForeColor = [Drawing.Color]::FromArgb(37, 63, 136)
        foreach ($button in $save, $cancel) {
            $button.Size = [Drawing.Size]::new(88, 34)
            $button.FlatStyle = 'Flat'
            $button.FlatAppearance.BorderSize = 0
            $button.UseVisualStyleBackColor = $false
        }
        $box.Add_TextChanged({ $save.Enabled = [bool]$box.Text.Trim() })
        $dialog.Controls.AddRange(@($label, $box, $save, $cancel))
        $dialog.AcceptButton = $save
        $dialog.CancelButton = $cancel
        $dialog.ActiveControl = $box
        $box.SelectAll()
        if ($dialog.ShowDialog($form) -eq [Windows.Forms.DialogResult]::OK) {
            return $box.Text.Trim()
        }
    } finally {
        $dialog.Dispose()
    }
}
$edit.Add_Click({
    if (!$script:activeGrid.CurrentRow -or $script:activeGrid.CurrentRow.Tag -isnot [int] -or $script:readOnly) { return }
    $index = $script:activeGrid.CurrentRow.Tag
    $item = $script:tasks[$index]
    $value = Show-TaskEditor $item.text
    if ($value -and $value.Length -le 300 -and $value -cne $item.text) { Update-Task $index $value $item.done }
    elseif ($value.Length -gt 300) { [void][Windows.Forms.MessageBox]::Show('待办内容最多 300 字。', '待办事项') }
})
foreach ($grid in @($list)) {
    $grid.Add_Enter({ $script:activeGrid = $this })
    $grid.Add_CellClick({
        if ($_.RowIndex -lt 0) { return }
        if ($this.Rows[$_.RowIndex].Tag -eq 'completed-group') {
            $script:showCompleted = !$script:showCompleted
            Render-Tasks
            return
        }
        if ($this.Rows[$_.RowIndex].Tag -isnot [int] -or $_.ColumnIndex -ne 0 -or $script:readOnly) { return }
        $script:activeGrid = $this
        $index = $this.Rows[$_.RowIndex].Tag
        $item = $script:tasks[$index]
        Update-Task $index $item.text (!$item.done)
    })
    $grid.Add_CellDoubleClick({
        if ($_.RowIndex -ge 0 -and $_.ColumnIndex -eq 1) { $script:activeGrid = $this; $edit.PerformClick() }
    })
    $grid.Add_KeyDown({
        if ($_.KeyCode -eq 'Delete') { $delete.PerformClick(); $_.SuppressKeyPress = $true }
        if ($_.KeyCode -eq 'F2') { $edit.PerformClick(); $_.SuppressKeyPress = $true }
    })
}
$list.Add_CellPainting({
    if ($_.RowIndex -lt 0 -or $_.ColumnIndex -ne 0) { return }
    if ($list.Rows[$_.RowIndex].Tag -is [int]) { return }
    $_.PaintBackground($_.ClipBounds, $true)
    $_.Paint($_.ClipBounds, [Windows.Forms.DataGridViewPaintParts]::Border)
    if ($list.Rows[$_.RowIndex].Tag -eq 'completed-group') {
        $arrow = if ($script:showCompleted) { '▾' } else { '▸' }
        $flags = [Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter
        [Windows.Forms.TextRenderer]::DrawText($_.Graphics, $arrow, $list.Font, $_.CellBounds, $_.CellStyle.ForeColor, $flags)
    }
    $_.Handled = $true
})
Render-Tasks
$tray = [Windows.Forms.NotifyIcon]::new()
$tray.Icon = [Drawing.Icon]::new((Join-Path $PSScriptRoot 'Todo.ico'))
$tray.Text = '待办事项'
$form.Icon = $tray.Icon
$menu = [Windows.Forms.ContextMenuStrip]::new()
$open = $menu.Items.Add('打开待办')
$exit = $menu.Items.Add('退出')
$tray.ContextMenuStrip = $menu
$show = { $form.Show(); $form.WindowState = 'Normal'; $form.Activate(); $inputBox.Focus() }
$open.Add_Click($show)
$tray.Add_MouseClick({ if ($_.Button -eq 'Left') { & $show } })
$context = [Windows.Forms.ApplicationContext]::new()
$exit.Add_Click({ $context.ExitThread() })
$form.Add_FormClosing({ if ($_.CloseReason -eq 'UserClosing') { $_.Cancel = $true; $form.Hide() } })
$openTimer = [Windows.Forms.Timer]::new()
$openTimer.Interval = 200
$openTimer.Add_Tick({ if ($openSignal.WaitOne(0)) { & $show } })
$openTimer.Start()
$tray.Visible = $true
if ($args -notcontains '-Tray') { & $show }
try { [Windows.Forms.Application]::Run($context) }
finally { $openTimer.Dispose(); $openSignal.Dispose(); $tray.Dispose(); $menu.Dispose(); $form.Dispose(); $mutex.ReleaseMutex(); $mutex.Dispose() }
