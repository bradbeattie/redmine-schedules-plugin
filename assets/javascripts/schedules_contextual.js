jQuery(document).ready( function() {
	jQuery(".schedule_entry").rightClick( function(e) {
		showScheduleMenu(e);
	});
	jQuery(".availability_entry").rightClick( function(e) {
		showAvailabilityMenu(e);
	});
	
	jQuery("body").click(function() {
		jQuery('#context-menu').hide();
	}); 
});

function showScheduleMenu(e) {
	showCommonMenu(e);
}

function showAvailabilityMenu(e) {
	showCommonMenu(e);
}

function showCommonMenu(e) {
	jQuery('#context-menu').hide();
    jQuery('#context-menu').css('left', e.pageX + 'px');
    jQuery('#context-menu').css('top', e.pageY + 'px');		

	jQuery.ajax({
		url: "schedule_menu",
		data: "entry="+e.target.id,
		cache: false,
		success: function(msg){
			jQuery("#context-menu").html(msg);
			jQuery("#context-menu").fadeIn(200);
		}
	});
}