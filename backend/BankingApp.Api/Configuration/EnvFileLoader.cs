namespace BankingApp.Api.Configuration
{
    public static class EnvFileLoader
    {
        public static void Load(string fileName = ".env")
        {
            var envPath = FindFile(fileName);
            if (envPath is null)
            {
                return;
            }

            foreach (var line in File.ReadAllLines(envPath))
            {
                var trimmedLine = line.Trim();
                if (string.IsNullOrWhiteSpace(trimmedLine) || trimmedLine.StartsWith('#'))
                {
                    continue;
                }

                var separatorIndex = trimmedLine.IndexOf('=');
                if (separatorIndex <= 0)
                {
                    continue;
                }

                var key = trimmedLine[..separatorIndex].Trim();
                var value = trimmedLine[(separatorIndex + 1)..].Trim().Trim('"');

                if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(key)))
                {
                    Environment.SetEnvironmentVariable(key, value);
                }
            }
        }

        private static string? FindFile(string fileName)
        {
            var directory = new DirectoryInfo(Directory.GetCurrentDirectory());
            while (directory is not null)
            {
                var candidatePath = Path.Combine(directory.FullName, fileName);
                if (File.Exists(candidatePath))
                {
                    return candidatePath;
                }

                directory = directory.Parent;
            }

            return null;
        }
    }
}
