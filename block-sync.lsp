; blocksync.lsp
; Provides the BLOCKSYNC command with Export and Import subcommands.

(vl-load-com)

(defun safe-command (&rest args)
	(apply 'command args))

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

(defun export-blocks-to-folder (names folder / fname)
	(if (null names) (progn (princ "\nNo blocks to export.") nil)
		(progn
			(setq old-cmdecho (getvar "CMDECHO"))
			(setvar "CMDECHO" 0)
			(foreach nm names
				(setq fname (strcat folder nm ".dwg"))
				(princ (strcat "\nExporting block: " nm " -> " fname))
				(command "._-WBLOCK" (strcat "\"" fname "\"") "B" nm "")
				)
			(setvar "CMDECHO" old-cmdecho)
			(princ (strcat "\nExported " (itoa (length names)) " blocks.")))))

(defun import-dwgs-from-folder (folder / files fullpath blkName fullSpec before after res action insertPt insertPtStr missingBlocks)
	(if (not (vl-file-directory-p folder)) (progn (princ "\nFolder not found.") nil)
		(progn
			(setq files (vl-directory-files folder "*.dwg" 1))
			(if (null files) (princ "\nNo .dwg files found in folder.")
				(progn
					(setq old-cmdecho (getvar "CMDECHO"))
					(setvar "CMDECHO" 0)
					(setq missingBlocks '())
					(foreach f files
						(setq fullpath (strcat folder f)
								blkName (vl-filename-base fullpath))
						(if (not (tblsearch "BLOCK" blkName))
							(setq missingBlocks (cons blkName missingBlocks))))
					(setq missingBlocks (reverse missingBlocks))
					(if missingBlocks
						(progn
							(initget "Skip Insert")
							(setq action (getkword "\nMissing blocks found. [Skip/Insert] all missing blocks: "))
							(if (or (equal action "Insert" 1) (equal action "I" 1))
								(setq insertPt (getpoint "\nSpecify insertion point for all missing blocks: ")))))
					(foreach f files
						(setq fullpath (strcat folder f)
								blkName (vl-filename-base fullpath)
								fullSpec (strcat blkName "=" fullpath))
						(princ (strcat "\nImporting: " blkName " <- " fullpath))
						(setq before (entlast))
						(if (tblsearch "BLOCK" blkName)
							(progn
								(setq res
									(vl-catch-all-apply
										'vl-cmdf
										(list "_.-INSERT" fullSpec "y" "0,0" "1" "0" "0")))
								(vl-catch-all-apply 'vl-cmdf (list "._CANCEL"))
								(if (vl-catch-all-error-p res)
									(princ (strcat "\nImport failed for: " fullpath))
									(progn
										(setq after (entlast))
										(if (and after (not (eq after before))) (entdel after)))))
							(progn
								(cond
									((or (equal action "Skip" 1) (equal action "S" 1))
										(princ "\nSkipped."))
									((or (equal action "Insert" 1) (equal action "I" 1))
										(setq res
											(vl-catch-all-apply
												'vl-cmdf
												(list "_.-INSERT" fullSpec insertPt "1" "1" "0")))
										(if (vl-catch-all-error-p res)
											(princ (strcat "\nInsert failed for: " fullpath))
											(princ (strcat "\nInserted block: " blkName))))
									(T (princ "\nUnknown option. Skipping block.")))))
						)
					(setvar "CMDECHO" old-cmdecho)
					(princ (strcat "\nImported " (itoa (length files)) " files."))
					)))))

(defun delete-folder-and-contents (folder / fso)
	(if (not (vl-file-directory-p folder)) (princ "\nFolder not found; nothing deleted.")
		(progn
			(setq fso (vlax-create-object "Scripting.FileSystemObject"))
			(vlax-invoke-method fso 'DeleteFolder folder)
			(vlax-release-object fso)
			(princ "\nFolder deleted."))))

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
				 (import-dwgs-from-folder folder)
				 (initget "Yes No")
				 (setq ans (getkword "\nDelete the source folder and its contents? [Yes/No]: "))
				 (if (and ans (or (equal ans "Yes" 1) (equal ans "Y" 1)))
					 (delete-folder-and-contents folder)
					 (princ "\nFolder preserved.")))))

		(T (princ "\nUnknown option. Use Export or Import.")))
	(princ))

(princ "\nCommand `blocksync` loaded. Type BLOCKSYNC to run.")

