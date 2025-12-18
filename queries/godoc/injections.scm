; Treesitter injection queries for godoc
; These inject the Go parser into specific regions of godoc output
; Inject Go syntax into package lines
((package_line) @injection.content
  (#set! injection.language "go"))

; Inject Go syntax into function lines
((func_line) @injection.content
  (#set! injection.language "go"))

; Inject Go syntax into function blocks
((func_block) @injection.content
  (#set! injection.language "go"))

; Inject Go syntax into type lines
((type_line) @injection.content
  (#set! injection.language "go"))

; Inject Go syntax into type blocks
((type_block) @injection.content
  (#set! injection.language "go"))

; Inject Go syntax into variable lines
((var_line) @injection.content
  (#set! injection.language "go"))

; Inject Go syntax into variable blocks
((var_block) @injection.content
  (#set! injection.language "go"))

; Inject Go syntax into constant lines
((const_line) @injection.content
  (#set! injection.language "go"))

; Inject Go syntax into constant blocks
((const_block) @injection.content
  (#set! injection.language "go"))

; Inject Go syntax into code blocks
((code_block) @injection.content
  (#set! injection.language "go"))
