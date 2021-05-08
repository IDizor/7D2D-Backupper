;
; This AutoHotkey script allows you to create/restore backups for the game '7 Days to Die' easily.
;
; How to use:
;   1. Install the AutoHotkey application if you don't have it.
;   2. Run this AHK script. The 7D2D icon will appear in the windows tray.
;
; Controls: (work in game Main Menu only)
;   F5 - Create a new backup for the latest played game.
;   F9 - Restore the latest backup for the latest played game.
;
; Backups are stored in "%APPDATA%\7DaysToDie\Backups\<MapName>\<GameName>" folder.
; Check the config section below for some options.

Menu, Tray, Icon, icon.png

; Config
SuspendGame = 1
EnableSounds = 1
BackupsLimit = 3 ; Backups limit per saved game.
CompressionLevel = NoCompression ; The compression level for backups. Values: NoCompression, Fastest, Optimal.
RestoringConfirmation = 1

; Constants
SavesDir = %APPDATA%\7DaysToDie\Saves
BackupsDir = %APPDATA%\7DaysToDie\Backups

; Sounds
SoundStart = sounds\start.mp3
SoundDone = sounds\done.mp3
SoundError = sounds\error.mp3

; Global variables
busy := 0

; Play sound on script start
PlaySound(SoundStart)

#IfWinActive, ahk_exe 7DaysToDie.exe
~F5:: ; Make backup
if (!busy)
{
  global busy
  busy := 1
  skipFinalErrorSound := 0
  saveDir := GetLatestPlayedGameDir()
  
  if (saveDir != "")
  {
    if (!IsSaveLocked(saveDir))
    {
      pathParts := StrSplit(saveDir, "\")
      saveName := pathParts[pathParts.MaxIndex()]
      mapName := pathParts[pathParts.MaxIndex() - 1]
      
      FormatTime, currentDateTime,, yyyy.MM.dd_HH.mm.ss
      backupToDir := BackupsDir "\" mapName "\" saveName
      backupFile := backupToDir "\" currentDateTime ".zip"
      
      FileCreateDir, %backupToDir%
      
      IfExist, %backupToDir%
      {
        try {
          SuspendGameProcess()          
          SplashTextOn , 300, 120, Creating a backup, `nCreating new backup, please wait...`n`nMap: %mapName%`nGame: %saveName%
          PlaySound(SoundStart)
          RunWait PowerShell.exe -Command Compress-Archive -LiteralPath '%saveDir%' -CompressionLevel %CompressionLevel% -DestinationPath '%backupFile%' -Force,, Hide
          
          IfExist, %backupFile%
          {
            SplashTextOff
            PlaySound(SoundDone)
            Sleep, 2000
            busy := 0
            DeleteOldBackups(backupToDir)
            ;MsgBox, %backupFile%
            return
          }
        } catch e {
          skipFinalErrorSound := 1
          PlaySound(SoundError)
          MsgBox , 0x1004, Error, % "An error occured at: " e.what "`nFile: " e.file "`nLine: " e.line "`n`nDo you want to review backups and saves in explorer?"
          IfMsgBox Yes
            OpenAppDataDir()
        } finally {
          SplashTextOff          
          ResumeGameProcess()
          busy := 0
        }
      }
    }
  }
  
  busy := 0
  if (!skipFinalErrorSound) {
    PlaySound(SoundError)
  }
}
return

#IfWinActive, ahk_exe 7DaysToDie.exe
~F9:: ; Restore backup
if (!busy)
{
  global busy
  busy := 1
  skipFinalErrorSound := 0
  saveDir := GetLatestPlayedGameDir()
  
  if (saveDir != "")
  {
    if (!IsSaveLocked(saveDir))
    {
      pathParts := StrSplit(saveDir, "\")
      saveName := pathParts[pathParts.MaxIndex()]
      mapName := pathParts[pathParts.MaxIndex() - 1]
      
      backupsLocation := BackupsDir "\" mapName "\" saveName
      backupFile := GetLatestBackup(backupsLocation)
      
      if (backupFile != "")
      {
        if (RestoringConfirmation) {
          MsgBox , 0x1004, Restoring Confirmation, % "Are you sure you want to restore the latest backup?`n`nBackup: " backupFile "`nMap: " mapName "`nGame: " saveName "`n`nCurrent progress in this game will be lost."
          IfMsgBox No
          {
            busy := 0
            return
          }
        }
        
        try {
          SuspendGameProcess()
          SplashTextOn , 300, 120, Restoring a backup, `nRestoring the latest backup, please wait...`n`nMap: %mapName%`nGame: %saveName%
          PlaySound(SoundStart)
          
          IfExist, %saveDir%_bak
          {
            FileRemoveDir, %saveDir%_bak , 1
            Sleep, 100
          }
          
          FileMoveDir, %saveDir%, %saveDir%_bak, R ; Rename
          
          IfNotExist, %saveDir%
          {
            RunWait PowerShell.exe -Command Expand-Archive -LiteralPath '%backupsLocation%\%backupFile%' -DestinationPath '%SavesDir%\%mapName%',, Hide
            
            IfExist, %saveDir%\Region
            {
              SplashTextOff
              FileRemoveDir, %saveDir%_bak , 1
              FileSetTime, , %saveDir%\main.ttw
              PlaySound(SoundDone)
              Sleep, 2000
              busy := 0
              return
            }
            else
            {
              ; Something went wrong
              Sleep, 100
              FileRemoveDir, %saveDir% , 1
              Sleep, 100
              FileMoveDir, %saveDir%_bak, %saveDir%, R ; Rename back
            }
          }
        } catch e {
          skipFinalErrorSound := 1
          PlaySound(SoundError)
          MsgBox , 0x1004, Error, % "An error occured at: " e.what "`nFile: " e.file "`nLine: " e.line "`n`nDo you want to review backups and saves in explorer?"
          IfMsgBox Yes
            OpenAppDataDir()
        } finally {
          SplashTextOff
          ResumeGameProcess()
          busy := 0
        }
      } else {
        skipFinalErrorSound := 1
        PlaySound(SoundError)
        MsgBox , 0x1004, No backup, % "There is no backup found for the latest played game: `n`nMap: " mapName "`nGame: " saveName "`n`nDo you want to review backups and saves in explorer?"
        IfMsgBox Yes
          OpenAppDataDir()
      }
    }
  }
  
  busy := 0
  if (!skipFinalErrorSound) {
    PlaySound(SoundError)
  }
}
return

;; ----------- 	THE FUNCTIONS   -------------------------------------
GetLatestPlayedGameDir()
{
  global SavesDir
  
  IfExist, %SavesDir%
  {
    filesList := ""
    Loop, Files, %SavesDir%\main.ttw , R
    {
      StringRight, dirSuffix, A_LoopFileDir, 4
      if (dirSuffix != "_bak") {
        filesList .= A_LoopFileTimeModified "," A_LoopFileDir "`r`n"
      }
    }
    
    if (filesList != "")
    {
      Sort, filesList, R
      saveDir := SubStr(filesList, 16, InStr(filesList, "`r") - 16)
      
      return saveDir
    }
  }
  
  return ""
}

IsSaveLocked(saveDir)
{
  IfExist, %saveDir%\Region
  {
    filesList := ""
    Loop, Files, %saveDir%\Region\*.*
    {
      filesList .= A_LoopFileFullPath "`r`n"
    }
    
    if (filesList != "")
    {
      firstFile := SubStr(filesList, 1, InStr(filesList, "`r") - 1)
      return IsFileLocked(firstFile)
    }
  }
  
  return 1
}

IsFileLocked(filePath)
{
  FileMove, %filePath%, %filePath%
  return Errorlevel != 0
}

GetLatestBackup(fromDir)
{
  IfExist, %fromDir%
  {
    filesList := ""
    Loop, Files, %fromDir%\*.zip
    {
      filesList .= A_LoopFileName "`r`n"
    }
    
    if (filesList != "")
    {
      Sort, filesList, R
      firstFile := SubStr(filesList, 1, InStr(filesList, "`r") - 1)
      return firstFile
    }
  }
  
  return ""
}

DeleteOldBackups(fromDir)
{
  global BackupsLimit
  
  IfExist, %fromDir%
  {
    filesList := ""
    Loop, Files, %fromDir%\*.zip
    {
      filesList .= A_LoopFileName "`r`n"
    }
    
    Sort, filesList, R
    filesArray := StrSplit(filesList, "`r`n")
    
    if (filesArray.MaxIndex() + 1 > BackupsLimit)
    {
      for index, element in filesArray
      {
        if (index > BackupsLimit && element != "")
        {
          FileDelete, %fromDir%\%element%
        }
      }
    }
  }
  
  return
}

PlaySound(soundFile) {
  global EnableSounds
  Sleep, 10
  if (EnableSounds) {
    SoundPlay, %soundFile%
  }
  return
}

OpenAppDataDir() {
  Run, explore %APPDATA%\7DaysToDie
  return
}

SuspendGameProcess() {
  global SuspendGame
  if (SuspendGame) {
    PID_or_Name = 7DaysToDie.exe
    PID := (InStr(PID_or_Name,".")) ? ProcExist(PID_or_Name) : PID_or_Name
    h := DllCall("OpenProcess", "uInt", 0x1F0FFF, "Int", 0, "Int", pid)
    If !h
      Return -1
    DllCall("ntdll.dll\NtSuspendProcess", "Int", h)
    DllCall("CloseHandle", "Int", h)
  }
  return
}

ResumeGameProcess() {
  global SuspendGame
  if (SuspendGame) {
    PID_or_Name = 7DaysToDie.exe
    PID := (InStr(PID_or_Name,".")) ? ProcExist(PID_or_Name) : PID_or_Name
    h := DllCall("OpenProcess", "uInt", 0x1F0FFF, "Int", 0, "Int", pid)
    If !h   
      Return -1
    DllCall("ntdll.dll\NtResumeProcess", "Int", h)
    DllCall("CloseHandle", "Int", h)
  }
  return
}

ProcExist(PID_or_Name="") {
  Process, Exist, % (PID_or_Name="") ? DllCall("GetCurrentProcessID") : PID_or_Name
  Return Errorlevel
}
;; ----------- 	END FUNCTIONS   -------------------------------------