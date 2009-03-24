jQuery(".schedule_entry_grid tbody td input:first-child").blur(function () {
	var cell = jQuery(this).parent();
	var index = jQuery(cell.parent().children()).index(cell) + 1;
	var grid = jQuery(this).parents("table.schedule_entry_grid");
	var sum = 0;
	var delta = 0;
	
	// Update the project boxes
	jQuery.each(grid.find("tbody tr td:nth-child("+index+")"), function() {
		var entry = jQuery(this).find("input:first-child");
		var hidden = jQuery(this).find("input:last-child");
		var entry_value = assure_non_negative(entry.val());
		var hidden_value = assure_non_negative(hidden.val());
		var value = positive_or_blank(entry_value);
		entry.val(value);
		hidden.val(value);

		// Update the column values
		delta += parseFloat(entry_value - hidden_value);
		sum += parseFloat(entry_value);
	});
	
	// Update the total text
	jQuery.each(grid.find("tfoot tr:last-child th:nth-child("+index+")"), function() {
		jQuery(this).text(positive_or_blank(sum));
	});
});

function positive_or_blank(value) {
	value = parseFloat(value);
	if (value <= 0 || isNaN(value)) {
		return "";
	} else {
		return value.toFixed(1);
	}
}

function assure_non_negative(value) {
	value = parseFloat(value);
	if (value <= 0 || isNaN(value)) {
		return 0.0;
	} else {
		return value.toFixed(1);
	}
}