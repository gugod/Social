$(function() {
    $("#text").focus();

    $("form#irc").bind("submit", function() {
        var ident = $("#ident").val();
        var text = $("#text").val();
        var channel = $("#channel").val();

        if (!text || !ident || !channel) return false;

        $.ajax({
            url: "/irc",
            data: $(this).serialize(),
            type: 'post',
            dataType: 'json',
            success: function(r) { $("#text").val("").focus(); }
        });
        return false;
    });

    $("#channels a").bind("click", function() {
        $("#channels").hide();
        $("#channel").val( $(this).text() );

        var channel_el_id = this.href.replace(/^.+#/, "");

        $("#channels-wrapper").scrollTop( $("#" + channel_el_id).position().top );
        $("#" + channel_el_id).scrollTop(0);

        $("#channels-wrapper .channel").hide();
        $("#" + channel_el_id).show().scrollTop(0);

        return false;
    });

    $("#channel").bind("click", function() {
        $("#channels").show();
        return false;
    });

    setTimeout(function() {
        $("#channels a:first").trigger("click");
    }, 1000);

    var onNewEvent = function(e) {
        try {
            var src    = e.avatar || ("http://www.gravatar.com/avatar/" + $.md5(e.ident || 'foo'));
            var name   = e.name   || e.ident || 'Anonymous';
            var avatar = $('<img/>').attr('src', src).attr('alt', name);

            avatar = $('<div/>').addClass('avatar').append(avatar);

            var message = $('<div/>').addClass('chat-message');
            if (e.text) message.text(e.text);
            if (e.html) message.html(e.html);
            message.find('a').oembed(null, { embedMethod: "append", maxWidth: 240 });
            var name = e.name || (e.ident ? e.ident.split('@')[0] : null);
            if (name)
                message.prepend($('<span/>').addClass('name').text(name+ ': '));

            var meta = $('<span/>').addClass('meta').text(' (' + e.time + ' from ' + e.address + ')');

            var channel_el_id = "channel-" + e.channel.toLowerCase().replace(/[^0-9a-z]/g, function(s) { return s.toString().charCodeAt(0) });

            if ($("#" + channel_el_id).size() == 0) {
                $("<div/>").appendTo("#channels-wrapper").attr({ "id": channel_el_id, "class": "channel" }).html("<ul class='messages'></ul>");
            }

            $('.messages', "#" + channel_el_id).prepend($('<li/>').addClass('message').addClass("clearfix").append(avatar).append(message).append(meta));
        } catch(e) { if (console) console.log(e) };
    }

    setTimeout(function() {
        if (typeof DUI != 'undefined') {
            var s = new DUI.Stream();
            s.listen('application/json', function(payload) {
                var event = eval('(' + payload + ')');
                onNewEvent(event);
            });
            s.load('/irc/mpoll?session=' + Date.now() + Math.random());
        } else {
            $.ev.handlers.message = onNewEvent;
            $.ev.loop('/irc/poll?session=' + Date.now() + Math.random());
        }
    }, 500);
});
