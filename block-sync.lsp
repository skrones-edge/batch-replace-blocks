; blocksync.lsp
; Provides the BLOCKSYNC command with Export and Import subcommands.

(vl-load-com)

(defun safe-command (&rest args)
	(apply 'command args))

(defun cancel-active-command ()
	(vl-catch-all-apply 'vl-cmdf (list "._ESC")))

(defun ensure-trailing-backslash (p)
	(if (= (substr p (strlen p) 1) "\\") p (strcat p "\\")))

(defun get-folder-from-user (prompt)
	(princ (strcat "\n" prompt))
	(setq sh (vlax-create-object "Shell.Application"))
	;; Use the new BrowseForFolder UI (BIF_NEWDIALOGSTYLE) and edit box (BIF_EDITBOX)
	;; BIF_NEWDIALOGSTYLE = 0x0040, BIF_EDITBOX = 0x0010 -> options = 0x0050 (80)
	(setq bfo (vlax-invoke-method sh 'BrowseForFolder 0 prompt 80 0))
	(setq path nil)
	(if bfo
		(progn
			(setq self (vlax-get-property bfo 'Self))
			(if self (setq path (vlax-get-property self 'Path)))
			(vlax-release-object sh)
			(if (and path (> (strlen path) 0)) (ensure-trailing-backslash path) nil))
		(progn
			(vlax-release-object sh)
			(setq res (vl-catch-all-apply 'getstring (list T "\nEnter full folder path: ")))
			(if (vl-catch-all-error-p res)
				;; user cancelled -> return nil
				nil
				(progn
					(setq fp res)
					(if (and fp (> (strlen fp) 0)) (ensure-trailing-backslash fp) nil))))))

(defun unique-block-names-from-ss (ss / i ent ed name names)
	(setq names '())
	(if ss
		(progn
			(setq i 0)
			(while (< i (sslength ss))
				(setq ent (ssname ss i)
							ed  (entget ent)
							name (cdr (assoc 2 ed)))
				(if (and name (not (member name names))) (setq names (cons name names)))
				(setq i (1+ i)))
			(reverse names))
		'()))

(defun export-blocks-to-folder (names folder / fname old-cmdecho old-filedia old-regenmode)
	(if (null names) (progn (princ "\nNo blocks to export.") nil)
		(progn
			(setq old-cmdecho (getvar "CMDECHO")
					old-filedia (getvar "FILEDIA")
					old-regenmode (getvar "REGENMODE"))
			(setvar "CMDECHO" 0)
			(setvar "FILEDIA" 0)
			(setvar "REGENMODE" 0)
			(foreach nm names
				(setq fname (strcat folder nm ".dwg"))
				(princ (strcat "\nExporting block: " nm " -> " fname))
				(command "._-WBLOCK" (strcat "\"" fname "\"") "B" nm "")
				)
			(setvar "CMDECHO" old-cmdecho)
			(setvar "FILEDIA" old-filedia)
			(setvar "REGENMODE" old-regenmode)
			(princ (strcat "\nExported " (itoa (length names)) " blocks.")))))

(defun import-dwgs-from-folder (folder / files fullpath blkName fullSpec before after res action existingBlocks missingBlocks f old-cmdecho old-filedia old-regenmode)
	(if (not (vl-file-directory-p folder)) (progn (princ "\nFolder not found.") nil)
		(progn
			(setq files (vl-directory-files folder "*.dwg" 1))
			(if (null files) (princ "\nNo .dwg files found in folder.")
				(progn
					(setq old-cmdecho (getvar "CMDECHO")
							old-filedia (getvar "FILEDIA")
							old-regenmode (getvar "REGENMODE"))
					(setvar "CMDECHO" 0)
					(setvar "FILEDIA" 0)
					(setvar "REGENMODE" 0)
					(setq existingBlocks '()
							missingBlocks '())
					(foreach f files
						(setq fullpath (strcat folder f)
								blkName (vl-filename-base fullpath))
						(if (tblsearch "BLOCK" blkName)
							(setq existingBlocks (cons blkName existingBlocks))
							(setq missingBlocks (cons blkName missingBlocks))))
					(setq existingBlocks (reverse existingBlocks)
							missingBlocks (reverse missingBlocks))
					(if missingBlocks
						(progn
							(initget "Skip Import")
							(setq action (getkword "\nNew block definitions found in the folder specified. [Skip/Import] all new block definitions?: "))))
					(foreach blkName existingBlocks
						(setq fullpath (strcat folder blkName ".dwg")
								fullSpec (strcat blkName "=" fullpath))
						(princ (strcat "\nRedefining block: " blkName " <- " fullpath))
						(setq before (entlast))
						(setq res
							(vl-catch-all-apply
								'vl-cmdf
								(list "_.-INSERT" fullSpec "0,0" "1" "1" "0")))
						(if (vl-catch-all-error-p res)
							(princ (strcat "\nRedefine failed for: " fullpath))
							(progn
								(setq after (entlast))
								(if (and after (not (eq after before))) (entdel after))
								(cancel-active-command)
								(princ (strcat "\nRedefined block: " blkName)))))
					(foreach blkName missingBlocks
						(setq fullpath (strcat folder blkName ".dwg")
								fullSpec (strcat blkName "=" fullpath))
						(princ (strcat "\nImporting new block: " blkName " <- " fullpath))
						(setq before (entlast))
						(cond
							((or (equal action "Skip" 1) (equal action "S" 1))
								(princ "\nSkipped."))
							((or (equal action "Import" 1) (equal action "I" 1))
								(setq res
									(vl-catch-all-apply
										'vl-cmdf
										(list "_.-INSERT" fullSpec "0,0" "1" "1" "0")))
								(if (vl-catch-all-error-p res)
									(princ (strcat "\nImport failed for: " fullpath))
									(progn
										(setq after (entlast))
										(if (and after (not (eq after before))) (entdel after))
										(cancel-active-command)
										(princ (strcat "\nImported block: " blkName)))))
							(T (princ "\nUnknown option. Skipping block."))))
					(setvar "CMDECHO" old-cmdecho)
					(princ (strcat "\nImported " (itoa (length files)) " files."))
					)))))


(defun c:blocksync (/ choice)
	(initget "Export Import")
	(setq choice (getkword "\nSelect subcommand [Export/Import]: "))
	(cond
		((or (equal choice "Export" 1) (equal choice "E" 1))
		 (princ "\n-- Export Blocks --")
		 (princ "\nSelect block references to export (pick objects): ")
		 (setq ss (ssget '((0 . "INSERT"))))
		 (if (not ss)
			 (princ "\nNo block references selected. Aborting.")
			 (progn
				 (setq names (unique-block-names-from-ss ss))
				 (if (null names)
					 (princ "\nNo block names found in selection.")
					 (progn
						 (setq folder (get-folder-from-user "Choose output folder:"))
						 (if (null folder)
							 (princ "\nNo folder provided. Aborting.")
							 (progn
								 (if (not (vl-file-directory-p folder))
									 (progn
										 (initget "Yes No")
										 (setq createAns (getkword "\nFolder does not exist. Create? [Yes/No]: "))
										 (if (or (and createAns (equal createAns "Yes" 1)) (and createAns (equal createAns "Y" 1)))
											 (vl-mkdir folder)
											 (progn (princ "\nFolder not created. Aborting.") (setq folder nil)))))
								 (if folder (export-blocks-to-folder names folder))
								 )))))) )

		((or (equal choice "Import" 1) (equal choice "I" 1))
		 (princ "\n-- Import Blocks --")
		 (setq folder (get-folder-from-user "Choose folder containing block .dwg files:"))
		 (if (null folder)
			 (princ "\nNo folder provided. Aborting.")
			 (progn
				 (import-dwgs-from-folder folder))))

		(T (princ "\nUnknown option. Use Export or Import.")))
	(princ))

(princ "\nCommand `blocksync` loaded. Type BLOCKSYNC to run.")

