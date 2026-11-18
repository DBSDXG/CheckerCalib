using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;

[assembly: System.Reflection.AssemblyTitle("棋盘标定板生成器（单文件版）")]
[assembly: System.Reflection.AssemblyProduct("棋盘标定板参数化模板")]
[assembly: System.Reflection.AssemblyDescription("自包含生成器：内嵌参数窗口、模型模板与 OpenSCAD 引擎")]
[assembly: System.Reflection.AssemblyFileVersion("1.2.0.0")]
[assembly: System.Reflection.AssemblyVersion("1.2.0.0")]

namespace CheckerboardStandalone
{
    internal static class Program
    {
        private const string Version = "1.3";
        private const string PayloadResourceName = "CheckerboardPayload.zip";

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool AttachConsole(int dwProcessId);

        private const int ATTACH_PARENT_PROCESS = -1;

        [STAThread]
        private static int Main(string[] args)
        {
            try
            {
                string appDir = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "CheckerboardGenerator", "v" + Version);
                string marker = Path.Combine(appDir, "extracted.txt");
                string script = Path.Combine(appDir, "generator.ps1");

                bool needExtract = !File.Exists(marker) || File.ReadAllText(marker).Trim() != Version || !File.Exists(script);
                if (needExtract)
                {
                    ShowSplash("首次运行：正在准备组件，请稍候…");
                    try
                    {
                        if (Directory.Exists(appDir)) { Directory.Delete(appDir, true); }
                        Directory.CreateDirectory(appDir);
                        ExtractPayload(appDir);
                        File.WriteAllText(marker, Version);
                    }
                    finally { HideSplash(); }
                }

                if (!File.Exists(script))
                {
                    MessageBox.Show(
                        "组件解压不完整。请删除以下文件夹后重试：\r\n" + appDir,
                        "无法启动", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return 1;
                }

                bool checkOnly = false;
                foreach (string a in args)
                {
                    if (string.Equals(a, "-CheckOnly", StringComparison.OrdinalIgnoreCase)) { checkOnly = true; }
                }

                string psArgs = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File \"" + script + "\"";
                string extra = string.Join(" ", args).Trim();
                if (extra.Length > 0) { psArgs = psArgs + " " + extra; }

                ProcessStartInfo psi = new ProcessStartInfo();
                psi.FileName = "powershell.exe";
                psi.Arguments = psArgs;
                psi.UseShellExecute = false;
                psi.CreateNoWindow = true;
                psi.WorkingDirectory = appDir;

                if (checkOnly)
                {
                    AttachConsole(ATTACH_PARENT_PROCESS);
                    Process p = Process.Start(psi);
                    p.WaitForExit();
                    return p.ExitCode;
                }

                Process.Start(psi);
                return 0;
            }
            catch (Exception ex)
            {
                MessageBox.Show("启动失败：" + ex.Message, "错误", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 1;
            }
        }

        private static Form splash;

        private static void ShowSplash(string text)
        {
            splash = new Form();
            splash.FormBorderStyle = FormBorderStyle.None;
            splash.StartPosition = FormStartPosition.CenterScreen;
            splash.ShowInTaskbar = false;
            splash.TopMost = true;
            splash.ClientSize = new System.Drawing.Size(320, 84);
            splash.BackColor = System.Drawing.Color.White;
            Label l = new Label();
            l.Text = text;
            l.Dock = DockStyle.Fill;
            l.TextAlign = System.Drawing.ContentAlignment.MiddleCenter;
            l.Font = new System.Drawing.Font("Microsoft YaHei UI", 10F);
            l.ForeColor = System.Drawing.Color.FromArgb(15, 23, 42);
            splash.Controls.Add(l);
            splash.Show();
            Application.DoEvents();
        }

        private static void HideSplash()
        {
            if (splash != null) { splash.Close(); splash.Dispose(); splash = null; }
        }

        private static void ExtractPayload(string appDir)
        {
            Assembly asm = Assembly.GetExecutingAssembly();
            using (Stream s = asm.GetManifestResourceStream(PayloadResourceName))
            {
                if (s == null) { throw new Exception("内嵌资源缺失"); }
                using (ZipArchive za = new ZipArchive(s, ZipArchiveMode.Read))
                {
                    foreach (ZipArchiveEntry e in za.Entries)
                    {
                        if (string.IsNullOrEmpty(e.Name)) { continue; }
                        string dest = Path.Combine(appDir, e.FullName.Replace('/', '\\'));
                        string dir = Path.GetDirectoryName(dest);
                        if (!Directory.Exists(dir)) { Directory.CreateDirectory(dir); }
                        using (Stream es = e.Open())
                        using (FileStream fs = File.Create(dest))
                        {
                            es.CopyTo(fs);
                        }
                    }
                }
            }
        }
    }
}
