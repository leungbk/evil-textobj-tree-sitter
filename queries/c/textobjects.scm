;; TODO: supported by official Tree-sitter  if (_)* is more than one node
;; Neovim: will only match if (_) is exactly one node
;(function_definition
  ;body:  (compound_statement
                          ;("{" (_)* @function.inner "}"))?) @function.outer

(declaration
  declarator: (function_declarator)) @function.outer

(function_definition
  body:  (compound_statement) @function.inner) @function.outer

(struct_specifier
  body: (_) @class.inner) @class.outer

(enum_specifier
  body: (_) @class.inner) @class.outer

; conditional
(if_statement
  consequence: (_)? @conditional.inner
  alternative: (_)? @conditional.inner
  ) @conditional.outer

(if_statement
  condition: (_) @conditional.inner)

; loops
(for_statement
  (_)? @loop.inner) @loop.outer
(while_statement
  (_)? @loop.inner) @loop.outer
(do_statement
  (_)? @loop.inner) @loop.outer


(compound_statement) @block.outer
(comment) @comment.outer

(call_expression) @call.outer
(call_expression (_) @call.inner)

; Statements

;(expression_statement ;; this is what we actually want to capture in most cases (";" is missing) probably
  ;(_) @statement.inner) ;; the other statement like node type is declaration but declaration has a ";"

(compound_statement
  (_) @statement.outer)

(field_declaration_list
  (_) @statement.outer)

(preproc_if
  (_) @statement.outer)

(preproc_elif
  (_) @statement.outer)

(preproc_else
  (_) @statement.outer)

((parameter_list
  ","  @parameter.outer._start . (parameter_declaration) @parameter.inner @parameter.outer._end)
 )
((parameter_list
  . (parameter_declaration) @parameter.inner @parameter.outer._start . ","?  @parameter.outer._end)
 )

((argument_list
  ","  @parameter.outer._start . (_) @parameter.inner @parameter.outer._end)
 )
((argument_list
  . (_) @parameter.inner @parameter.outer._start . ","?  @parameter.outer._end)
 )

