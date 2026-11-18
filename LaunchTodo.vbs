Set shell = CreateObject("WScript.Shell")
Set fs = CreateObject("Scripting.FileSystemObject")
root = fs.GetParentFolderName(WScript.ScriptFullName)
exe = shell.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
q = Chr(34)
command = q & exe & q & " -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File " & q & root & "\Todo.ps1" & q
If WScript.Arguments.Count > 0 Then
    If WScript.Arguments(0) = "-Tray" Then command = command & " -Tray"
End If
shell.Run command, 0, False
