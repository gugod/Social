$(function() {
    $("#channels a").bind("click", function() {
        $("#channels").hide();
        $(".channel").hide();

        var channel_el_id = this.href.replace(/^.+#/, "");
        $("#" + channel_el_id).show();

        $("#channel").val( $(this).text() );
        $("#text").focus();

        return false;
    });

    $("#channel").bind("click", function() {
        $("#channels").show();
        return false;
    });

    setTimeout(function() {
        $("#channels a:first").trigger("click");
    }, 1000);
});
