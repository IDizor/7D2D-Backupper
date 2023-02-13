;
; This is an AutoHotkey script that allow you to create/restore backups for the game '7 Days to Die' easily.
; Version 2.0
;
; How to use:
;   1. Install the AutoHotkey application if you don't have it.
;   2. Run this AHK script. The 7D2D icon will appear in the windows tray.
;
; Controls: (work in the game Main Menu only)
;   F5 - Create a new backup for the selected game.
;   F9 - Restore the selected backup.
;
; Backups are stored in "%APPDATA%\7DaysToDie\Backups\<MapName>\<GameName>" folder.
; Check the config section below for some options.

Menu, Tray, Icon, icon.png

; Config
SuspendGame = 1
EnableSounds = 1
BackupsLimit = 5 ; Backups limit per single game (save).
CompressionLevel = NoCompression ; The compression level for backups. Values: NoCompression, Fastest, Optimal.

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
  
  if (!IsPlayingNow())
  {
    selectedGame := GuiSelectGameToBackup()
    if (selectedGame != "")
    {
      saveDir := SavesDir . "\" . selectedGame

      if (!IsSaveLocked(saveDir))
      {
        pathParts := StrSplit(selectedGame, "\")
        mapName := pathParts[1]
        saveName := pathParts[2]
        
        FormatTime, currentDateTime,, yyyy.MM.dd_HH.mm.ss
        backupToDir := BackupsDir "\" mapName "\" saveName
        backupFile := backupToDir "\" currentDateTime ".zip"
        
        FileCreateDir, %backupToDir%
        
        IfExist, %backupToDir%
        {
          try {
            SuspendGameProcess()          
            SplashTextOn , 300, 120, Creating a backup, `nCreating new backup, please wait...`n`nGame: %saveName%`nOn the map: %mapName%
            PlaySound(SoundStart)
            RunWait PowerShell.exe -Command Compress-Archive -LiteralPath '%saveDir%' -CompressionLevel %CompressionLevel% -DestinationPath '%backupFile%' -Force,, Hide
            
            IfExist, %backupFile%
            {
              SplashTextOff
              PlaySound(SoundDone)
              Sleep, 20
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
  }
  
  busy := 0
  if (!skipFinalErrorSound) {
    PlaySound(SoundError)
  }
}
return
#IfWinActive

#IfWinActive, ahk_exe 7DaysToDie.exe
~F9:: ; Restore backup
if (!busy)
{
  global busy
  busy := 1
  skipFinalErrorSound := 0

  if (!IsPlayingNow())
  {
    selectedBackup := GuiSelectBackup()
    if (selectedBackup != "")
    {
      saveDir := SavesDir . "\" . SubStr(selectedBackup, 1, InStr(selectedBackup, "\", false, 0) - 1)
      
      if (!IsSaveLocked(saveDir))
      {
        pathParts := StrSplit(selectedBackup, "\")
        mapName := pathParts[1]
        saveName := pathParts[2]

        backupFile := BackupsDir . "\" . selectedBackup
        
        try {
          SuspendGameProcess()
          SplashTextOn , 300, 120, Restoring a backup, `nRestoring the selected backup, please wait...`n`nMap: %mapName%`nGame: %saveName%
          PlaySound(SoundStart)
          
          IfExist, %saveDir%_bak
          {
            FileRemoveDir, %saveDir%_bak , 1
            Sleep, 100
          }
          
          FileMoveDir, %saveDir%, %saveDir%_bak, R ; Rename
          
          IfNotExist, %saveDir%
          {
            RunWait PowerShell.exe -Command Expand-Archive -LiteralPath '%backupFile%' -DestinationPath '%SavesDir%\%mapName%',, Hide
            
            IfExist, %saveDir%\Region
            {
              SplashTextOff
              FileRemoveDir, %saveDir%_bak , 1
              PlaySound(SoundDone)
              Sleep, 20
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
      }
    } else {
      skipFinalErrorSound := 1
    }
  }
  
  busy := 0
  if (!skipFinalErrorSound) {
    PlaySound(SoundError)
  }
}
return
#IfWinActive

;; ----------- 	THE FUNCTIONS   -------------------------------------
GuiSelectGameToBackup()
{
  global SGGuiSelectedGame
  global SGGuiSelectedBackup
  global SGGuiOk
  result := ""
  games := GetAllPlayedGames()

  if (ObjLength(games))
  {
    Gui, SGGui: -MaximizeBox -MinimizeBox +AlwaysOnTop +DPIScale
    Gui, SGGui: Font, s11
    Gui, SGGui: Margin, 12, 12
    Gui, SGGui: Add, Text,, Select a game to backup:
    Gui, SGGui: Add, DropDownList, vSGGuiSelectedGame w300 R8, % ArrayToDropDownChoices(games)
    Gui, SGGui: Add, Button, vSGGuiOk gSGOk h28 w80 xm+50 default, Backup
    Gui, SGGui: Add, Button, gCancel h28 w80 xp+120 yp, Cancel
    Gui, SGGui: Show,, Create 7DtD game backup

    WinWaitClose, Create 7DtD game backup
    Gui, SGGui: Destroy
    return result

    SGOk:
    {
      Gui, SGGui:Submit, NoHide
      result := SGGuiSelectedGame
      Gui, SGGui: Destroy
      return
    }
  }

  return result
}

GuiSelectBackup()
{
  global RCGuiSelectedGame
  global RCGuiSelectedBackup
  global RCGuiOk
  result := ""
  saves := GetSavesWhichHaveBackups()

  if (ObjLength(saves))
  {
    backups := GetBackups(saves[1])

    Gui, RCGui: -MaximizeBox -MinimizeBox +AlwaysOnTop +DPIScale
    Gui, RCGui: Font, s11
    Gui, RCGui: Margin, 12, 12
    Gui, RCGui: Add, Text,, Select map\game:
    Gui, RCGui: Add, DropDownList, vRCGuiSelectedGame gRCGameSelected w300 R8, % ArrayToDropDownChoices(saves)
    Gui, RCGui: Add, Text,, ATTENTION:`nCurrent progress in this game will be lost.
    Gui, RCGui: Add, Text,, Select a backup file to restore:
    Gui, RCGui: Add, DropDownList, vRCGuiSelectedBackup w300 R8, % ArrayToDropDownChoices(backups)
    Gui, RCGui: Add, Button, vRCGuiOk gRCOk h28 w80 xm+50 default, Restore
    Gui, RCGui: Add, Button, gCancel h28 w80 xp+120 yp, Cancel
    Gui, RCGui: Show,, Restore 7DtD Backup

    WinWaitClose, Restore 7DtD Backup
    Gui, RCGui: Destroy
    return result

    RCGameSelected:
    {
      Gui, RCGui:Submit, NoHide
      backups := ArrayToDropDownChoices(GetBackups(RCGuiSelectedGame))
      GuiControl, RCGui:, RCGuiSelectedBackup, |%backups%
      return
    }

    RCOk:
    {
      Gui, RCGui:Submit, NoHide
      result := RCGuiSelectedGame . "\" . RCGuiSelectedBackup
      Gui, RCGui: Destroy
      return
    }
  }

  return result
}

GetBackups(fromDir)
{
  global BackupsDir
  backups := []
  IfExist, %BackupsDir%\%fromDir%
  {
    fileList := ""
    Loop, Files, %BackupsDir%\%fromDir%\*.zip
      fileList .= A_LoopFileName "`n"

    if (fileList != "")
    {
      Sort, fileList, R
      Loop, Parse, fileList, "`n"
      {
        backups.Push(A_LoopField)
      }
    }
  }

  return backups
}

GetSavesWhichHaveBackups()
{
  global SavesDir
  global BackupsDir
  result := []

  IfExist, %SavesDir%
  {
    savesList := ""
    Loop, Files, %SavesDir%\main.ttw , R
    {
      StringRight, dirSuffix, A_LoopFileDir, 4
      if (dirSuffix != "_bak") {
        savesList .= A_LoopFileTimeModified "," A_LoopFileDir "`n"
      }
    }
    StringTrimRight, savesList, savesList, 1
    
    if (savesList != "")
    {
      savesNames := ""
      Sort, savesList, R
      Loop, Parse, savesList, "`n"
      {
        StringLen, saveLength, A_LoopField
        StringGetPos, fromIndex, A_LoopField, \, R2
        StringRight, saveName, A_LoopField, saveLength - fromIndex - 1
        savesNames .= saveName "`n"
      }
      StringTrimRight, savesNames, savesNames, 1

      if (savesNames != "")
      {
        Loop, Parse, savesNames, "`n"
        {
          if (FileExist(BackupsDir "\" A_LoopField "\*.zip"))
          {
            result.Push(A_LoopField)
          }
        }
      }
    }
  }

  return result
}

GetAllPlayedGames()
{
  global SavesDir
  result := []

  IfExist, %SavesDir%
  {
    savesList := ""
    Loop, Files, %SavesDir%\main.ttw , R
    {
      StringRight, dirSuffix, A_LoopFileDir, 4
      if (dirSuffix != "_bak") {
        savesList .= A_LoopFileTimeModified "," A_LoopFileDir "`n"
      }
    }
    StringTrimRight, savesList, savesList, 1
    
    if (savesList != "")
    {
      savesNames := ""
      Sort, savesList, R
      Loop, Parse, savesList, "`n"
      {
        StringLen, saveLength, A_LoopField
        StringGetPos, fromIndex, A_LoopField, \, R2
        StringRight, saveName, A_LoopField, saveLength - fromIndex - 1
        result.Push(saveName)
      }
    }
  }
  
  return result
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

IsPlayingNow()
{
  global SavesDir
  games := GetAllPlayedGames()
  for i, game in games
  {
    gameDir := SavesDir . "\" . game
    if (IsSaveLocked(gameDir))
    {
      return true
    }
  }
  return false
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

ArrayToDropDownChoices(arr)
{
  choices := ""
  for i, v in arr
  {
    if (v != "")
    {
      choices .= v "|"
      if (i == 1)
      {
        choices .= "|"
      }
    }
  }
  return choices
}
;; ----------- 	END FUNCTIONS   -------------------------------------