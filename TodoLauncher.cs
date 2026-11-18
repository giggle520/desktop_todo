using System;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading;
using System.Windows.Forms;

internal static class TodoLauncher
{
    [STAThread]
    private static void Main(string[] args)
    {
        try
        {
            using (var runspace = RunspaceFactory.CreateRunspace())
            {
                runspace.ApartmentState = ApartmentState.STA;
                runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
                runspace.Open();
                using (var shell = PowerShell.Create())
                {
                    shell.Runspace = runspace;
                    shell.AddCommand(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Todo.ps1"));
                    foreach (string arg in args) shell.AddArgument(arg);
                    shell.Invoke();
                    if (shell.HadErrors)
                        MessageBox.Show(shell.Streams.Error[0].ToString(), "待办事项");
                }
            }
        }
        catch (Exception error)
        {
            MessageBox.Show(error.Message, "待办事项");
        }
    }
}
