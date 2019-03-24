if need_table(in_domain({'check_connection'}), nil, false) then
	need_string_array_match(in_domain({'check_connection', 'targets'}), '^[%x:]+$')
end
