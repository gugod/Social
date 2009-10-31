jQuery(function($) {

    var channel = location.hash;

    if (!channel) return;

    $("input[name=channel]").val(channel);

    var clientId = Date.now().toString() + Math.random().toString().replace(".", "");

    $.ev.loop('/comet/channel/' + channel.replace(/^#/, "") + '/stream/' + clientId, {
        "irc": function(ev) {
            var nick = ev.data[0];
            var text = ev.data[1];

            $("<p/>").html(
                "<span>" + nick +  "</span>: " + text
            ).appendTo("#messages");

            $("#messages").scrollTop( $("#messages").height() );
        }
    });

    $("#say").submit(function(e) {
        $.post(
            $(this).attr("action"),
            $(this).serialize(), function() {
             $("#say input[name=text]").focus().val("");
            });
        return false;
    });

    $("#say input[name=text]").focus();

});
