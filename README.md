## Open CloudServer (OCS) Operations ToolKit

OCS Deployment Operations Toolkit
The Open CloudServer (OCS) Operations Toolkit is a collection of scripts and utilities for updating, diagnosing, and testing OCS servers and chassis managers.  This Toolkit provides a one stop shop for utilities, tests and diagnostics that provide: 

- Diagnostics 
	o Identify defective components such as HDD, DIMM, and processor 
	o View, log, and compare configurations  
	o Read, clear and log errors 

- Stressors 
	o System stress tests to identify intermittent problems 
	o Component specific stress tests  
	o Cycling tests to identify intermittent initialization problems 

-  Updates 
	o Update programmable components such as BIOS and BMC 
	o Batch update of all programmable components   

- Miscellaneous 
	o Debug functions to execute IPMI and REST commands  

The Toolkit runs on 64 bit versions of WinPE version 5.1 or later, Windows Server 2012 or later, and Windows 8.1 or later.   The Toolkit can be deployed on bootable WinPE USB flash drives, WinPE RAM drives (from PXE Server), and drives with the Windows Server and Desktop Operating Systems.

The intent of this community project is to collaborate with Open Compute Project Foundation (OCP) to build a thriving ecosystem of OSS within OCP and contribute this project to OCP. 

If your intent is to use the Operations Toolkit software without contributing back to this project, then use the MASTER branch which holds the approved and stable public releases. 

If your goal is to improve or extend the code and contribute back to this project, then you should make your changes in, and submit a pull request against, the DEVELOPMENT branch. Read through our wiki section on how to contribute for a walk-through of the contribution process. 

All new work should be in the development branch. Master is now reserved to tag builds 


## Quick Start

- Clone the repo: git clone https://github.com/MSOpenTech/OCSOperationsToolKit.git

- Download the zip version of the repo (see the right-side pane)

Additional helpful information can be found in OCSToolsUserGuide.PDF


## Components Included 

-Collection of scripts and utilities for updating, diagnosing, and testing OCS servers and chassis managers. 

## Prerequisites

-PowerShell ExecutionPolicy must allow script execution 

	The Toolkit requires the PowerShell execution policy be set to allow the running of scripts.  One possible way to enable script execution is to run this command: 
	PowerShell -Command Set-ExecutionPolicy RemoteSigned -Force 

-Run As Administrator 

	Many of the commands must be run as administrator because they read low level hardware information.  If commands are not run as an administrator they may return 		incomplete or incorrect information. 
	Note that starting the Toolkit using the desktop shortcut automatically runs the Toolkit as administrator.  

-PowerShell Version 3.0 or later 
	The Toolkit requires PowerShell version 3.0 or later.  Windows Server 2012 and WinPE 5.1 (or later) include a PowerShell version that meets this requirement.  Older 	versions of Windows (ie: XP) would require installing version 3.0 of PowerShell separately.  


## Test Instructions

Detail helpful information can be found in OCSToolsUserGuide.PDF