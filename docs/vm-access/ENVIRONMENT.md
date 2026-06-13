# VM Environment Discovery

## Application: WEALTH (Momentum Metropolitan / MMI Holdings)

### Deployment Architecture

- **Internal update server**: https://internal-investments.mmiholdings.com/gemstoneflasks3proxy/
- **GemStone server hostname**: invgemprd101.metmom.mmih.biz
- **GemStone server IP**: 10.241.132.122
- **Organization**: MMI Holdings (Momentum Metropolitan)

### Launch Sequence (VisualworksSystem.bat)

1. Downloads latest `mas.im` from S3 proxy
2. Registers `wealth` service on port 10098/tcp
3. Runs DoUpdates.bat (JScript) to sync scripts and local files
4. Sets working dir to `C:\WEALTH\visualworks931\`
5. Launches: `Vwnt.exe mas.im`

### Currently Running Instance

The running VW is NOT the deployed WEALTH app - it's the **SDK dev image**:
- Executable: `C:\visualworks931\bin\win64\visual.exe`
- Image (likely): `C:\visualworks931\image\storeDev64.im`
- Window title: "Workspace" (dev environment)

### Available VW Executables

| Executable | Purpose |
|---|---|
| visual.exe | Full GUI VW with all tools |
| VisualWorks.exe | Standard GUI launcher |
| vwnt.exe | GUI VW (Windows native) |
| vwntconsole.exe | **Headless console** - can evaluate Smalltalk without GUI |
| vwntoe.dll | Object Engine DLL |

### VW Images

| Image | Location | Purpose | Last Modified |
|---|---|---|---|
| storeDev64.im | C:\visualworks931\image\ | Development | 2026-05-30 |
| storeTst64.im | C:\visualworks931\image\ | Testing | 2026-04-07 |
| storepre64.im | C:\visualworks931\image\ | Pre-production | 2026-03-19 |
| storeDev64TM.im | C:\visualworks931\image\ | Dev + Test Mentor | 2026-04-13 |
| storeTst64TM.im | C:\visualworks931\image\ | Test + Test Mentor | 2026-04-21 |
| mas.im | C:\WEALTH\visualworks931\ | Deployed MAS app | 2026-03-23 |
| mwi.im | C:\WEALTH\visualworks931\ | Deployed MWI app | 2026-03-23 |

### GemStone GCI Libraries (C:\WEALTH\GBS\)

Latest version: **3.7.4.3** (2026-01-15)
- libgcirpc-3.7.4.3-64.dll (RPC client)
- libgcits-3.7.4.3-64.dll (Thread-safe client)
- libssl-3.7.4.3-64.dll (TLS)

History of versions: 2.4.4, 3.4.4, 3.4.5, 3.5.4-3.5.8, 3.6.6, 3.6.8, 3.7.4.3

### Network Services (from services file)

| Service | Port | Protocol |
|---|---|---|
| wealth | 10098 | tcp |
| training | 10095 | tcp |
| mwipreldi | 10098 | tcp |
| mwitrn | 10065 | tcp |
| mwiprodldi | 10075 | tcp |
| maspreldi | 10099 | tcp |
| mwitst | 10065 | tcp |

### GemStone Deploy Scripts

- `C:\visualworks931\deploy.gs` (36.5 MB - GemStone fileout, updated 2026-05-31)
- `C:\visualworks931\testCases.gs` (18 MB - test cases fileout, updated 2026-05-31)
- `C:\visualworks931\version.topaz` contains: `!MAS INT V436.14.0`

### Other Infrastructure

- **PIP config**: `C:\pip\config\pip.cnf` / `pipProd.cnf` (Python/pip is used somewhere)
- **SSH keys**: `C:\visualworks931\image\putty.ppk` (for GemStone server access)
- **Test Mentor license**: `C:\visualworks931\image\stmreg.dat`, `C:\WEALTH\image\stmreg.dat`
- **herald.bmp**: `C:\WEALTH\visualworks\herald.bmp` (splash screen)

### Key Insight: Headless Smalltalk Evaluation

`C:\visualworks931\bin\win64\vwntconsole.exe` can run Smalltalk code headlessly.
This is the entry point for programmatic Smalltalk execution without GUI interaction.

Typical usage:
```
vwntconsole.exe <image.im> -doit "<smalltalk expression>"
```

Or with a script file:
```
vwntconsole.exe <image.im> -filein script.st
```
