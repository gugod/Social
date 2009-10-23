(function($) {

    var clientId = Date.now().toString() + Math.random().toString().replace(".", "");

    $.ev.loop('/comet/channel/jabbot/stream/' + clientId, {
        "irc": function(ev) {
            var nick = ev.data[0];
            var text = ev.data[1];

            $("<p/>").html(
                "<span>" + nick +  "</span>: " + text
            ).prependTo("#messages");
        }
    });

})(jQuery);
