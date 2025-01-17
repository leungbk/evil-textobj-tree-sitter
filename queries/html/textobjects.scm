(element) @function.outer

(element (start_tag) . (_) @function.inner . (end_tag))

((element (start_tag) . (_)  @function.inner._start (_)  @function.inner._end . (end_tag))
 )

(script_element) @function.outer
(script_element (start_tag) . (_) @function.inner . (end_tag))

(style_element) @function.outer
(style_element (start_tag) . (_) @function.inner . (end_tag))

((element (start_tag (tag_name) @_tag)) @class.outer
 (#match? @_tag "^(html|section|h[0-9]|header|title|head|body)$"))

((element (start_tag (tag_name) @_tag) . (_) @class.inner . (end_tag))
 (#match? @_tag "^(html|section|h[0-9]|header|title|head|body)$"))

((element (start_tag (tag_name) @_tag) . (_)  @class.inner._start (_)   @class.inner._end . (end_tag))
 (#match? @_tag "^(html|section|h[0-9]|header|title|head|body)$")
 )

