# Lime aac auto downloader

Lime aac için yapılmıştır.

### https://discord.gg/TEMbNBdEb3

Önerileriniz ve şikayetleriniz için discord sunucumuza katılabilirsiniz.

### Gereksinimler
* Windows İşletim Sistemi.
* PowerShell 5.1 veya üzeri versiyon.

### Çalıştırma
PowerShell'i yönetici açıp şu komutu girerek çalıştırabilirsiniz:
```powershell
$script = Invoke-RestMethod "https://raw.githubusercontent.com/FlaxerzNO1/Lime-auto-downloader-/main/Lime auto downloader.ps1"
$script = $script.TrimStart([char]0xFEFF)
Invoke-Expression $script
```
böyle olmasının sebebi UTF-8 ile UTF-8 BOM arası fark Türkçe karakter desteği olması

### indirerek
PowerShell'i yönetici açıp şu komutu girerek çalıştırabilirsiniz:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
   ./Lime auto downloader.ps1
   ```
