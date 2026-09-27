@echo off
cd /d "C:\Goblin House\Investigative-Nexus"

rem Log goes to the repo's PARENT folder: guaranteed to exist, outside the
rem repo so it never gets committed, and easy to find. %USERPROFILE%\Desktop
rem does not exist when OneDrive has redirected the Desktop folder.
set "LOG=C:\Goblin House\deploy-log.txt"

(
echo ================= GOBLIN HOUSE DEPLOY =================
echo.
echo --- does admin-vtubers.ts exist on disk? ---
if exist "artifacts\api-server\src\routes\admin-vtubers.ts" (
  echo YES - file is present
) else (
  echo NO  - FILE IS MISSING, this is why the build fails
)
echo.
echo --- is it known to git? [blank means NOT tracked] ---
git ls-files artifacts/api-server/src/routes/admin-vtubers.ts
echo.
echo --- other files I added [blank means NOT tracked] ---
git ls-files artifacts/api-server/src/lib/nav.ts artifacts/api-server/src/routes/everything.ts artifacts/api-server/public/crinkle-plate.png
echo.
echo --- line 125 of index.ts ---
powershell -NoProfile -Command "(Get-Content 'artifacts\api-server\src\routes\index.ts')[124]"
echo.
echo --- branch / tracking ---
git status -sb
echo.
echo --- staging ---
git add -A
echo.
echo --- what is staged ---
git diff --cached --name-status
echo.
echo --- committing ---
git commit -m "deploy"
echo.
echo --- pushing ---
git push
echo.
echo --- last 3 commits, with files ---
git log --oneline --name-status -3
echo.
echo ================= END =================
) > "%LOG%" 2>&1

type "%LOG%"
echo.
echo ============================================================
echo  Saved to:  C:\Goblin House\deploy-log.txt
echo  Drag that file into the chat.
echo ============================================================
pause
