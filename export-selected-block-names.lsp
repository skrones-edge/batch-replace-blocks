;; Export selected block names to CSV
;; Load with: (load "export-selected-block-names.lsp")
;; Run with: EXPORTBLKCSV

(progn
  (vl-load-com)

  (defun c:EXPORTBLKCSV (/ sel filePath outFile count ent obj name)
    (setq count 0)

    ;; Select block references with a standard interactive prompt
    (if (setq sel (ssget "_:L" '((0 . "INSERT"))))
      (progn
        ;; Ask for the CSV output file using a simple default filename
        (setq filePath (getfiled "Save CSV As"
                                 "selected-block-names.csv"
                                 "csv"
                                 1))

        (if filePath
          (if (setq outFile (open filePath "w"))
            (progn
              (write-line "BlockName" outFile)

              (while (< count (sslength sel))
                (setq ent (ssname sel count)
                      obj (vlax-ename->vla-object ent)
                      name (vla-get-EffectiveName obj))

                (if name
                  (write-line name outFile)
                )

                (setq count (1+ count))
              )

              (close outFile)
              (princ (strcat "\nExported " (itoa count) " block name(s) to: " filePath))
            )
            (princ "\nUnable to create the CSV file.")
          )
          (princ "\nNo output file selected.")
        )
      )
      (princ "\nNo blocks were selected.")
    )

    (princ)
  )
)
