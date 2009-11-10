if (navigator.standalone) {
    $("body").addClass("full-screen");
}


function padzero(x) {
    if (x < 10) return "0" + x;
    return x;
};

var Social = {};
Social.Irc = {};

function scroll_to_bottom() {
    setTimeout(function() {
        $("#channels-wrapper").scrollTop( $("#channels-wrapper").get(0).scrollHeight );
    }, 300);
}

function time_text(x) {
    var t = new Date( Date.parse(x) );
    var time_text = padzero(t.getHours()) + ":" + padzero(t.getMinutes());
    return time_text;
}


var $channel_div_for = function(channel) {
    var channel_el_id = "channel-" + channel.toLowerCase().replace(/[^0-9a-z]/g, function(s) { return s.toString().charCodeAt(0) });

    if ($("#" + channel_el_id).size() == 0) {
        $("<div/>").appendTo("#channels-wrapper").attr({ "id": channel_el_id, "class": "channel" }).html("");
    }

    return $("#" + channel_el_id);
}

Social.Irc.append_event_line = function(e, message_body) {
    var name   = e.name || e.ident || 'Anonymous';

    var $line = $('<div/>').attr({'class': 'line event', 'nick': name, 'type': e.type});

    var $message = $('<span/>').attr({"class": "message", "type": e.type }).text(message_body);

    $line
        .append( $('<span/>').attr({"class": "time", "time": e.time }).text(time_text(e.time)) )
        .append($message);

    $channel_div_for(e.channel).append( $line );
    scroll_to_bottom();

    return $line;
};

Social.Irc.Handlers = {
    "join": function(e) {
        var name   = e.name || e.ident || 'Anonymous';
        Social.Irc.append_event_line(e, name + " has joined " + e.channel);
    },

    "part": function(e) {
        var name   = e.name || e.ident || 'Anonymous';
        Social.Irc.append_event_line(e, name + " has parted " + e.channel);
    },

    "privmsg": function(e) {
        var type   = "text";
        var name   = e.name   || e.ident || 'Anonymous';

        var $line = $('<div/>').attr({'class': 'line ' + type, 'nick': name, 'type': type});

        var $message = $('<span/>').attr({"class": "message", "type": e.type });
        if (e.text) $message.text(e.text);
        if (e.html) $message.html(e.html);
        $message.find('a').oembed(null, { embedMethod: "append", maxWidth: 240 });

        $line
            .append( $('<span/>').attr({"class": "time", "time": e.time }).text(time_text(e.time)) )
            .append( $('<span/>').addClass('sender').text(name + ": ") )
            .append($message);

        $channel_div_for(e.channel).append( $line );

        scroll_to_bottom();
    }
};

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
            success: function(r) {
                $("#text").val("").focus();
                $("#channels-wrapper").scrollTop(599999);
            }
        });
        return false;
    });

    $("#channels a").bind("click", function() {
        $("#channels").hide();
        $("#channel").val( $(this).text() );

        var channel_el_id = this.href.replace(/^.+#/, "");

        $("#channels-wrapper .channel").hide();
        $("#" + channel_el_id).show().scrollTop(0);

        return false;
    });

    $("#channel").bind("click", function() {
        $("#channels").show();
        return false;
    });

    $("#channels a:first").trigger("click");

    var onNewEvent = function(e) {
        try {
            var type   = e.type == "privmsg" ? "text" : "event";
            var name   = e.name   || e.ident || 'Anonymous';

            var $line = $('<div/>').attr({
                'class': 'line ' + type,
                'nick': name,
                'type': type
            });

            $line.find('a').oembed(null, { embedMethod: "append", maxWidth: 240 });

            var t = new Date( Date.parse(e.time) );
            var time_text = padzero(t.getHours()) + ":" + padzero(t.getMinutes());

            $line.append( $('<span/>').attr({"class": "time", "time": e.time }).text(time_text) );
            $line.append( $('<span/>').addClass('sender').text(name + ": ") );

            var $message = $('<span/>').attr({"class": "message", "type": type });
            if (e.text) $message.text(e.text);
            if (e.html) $message.html(e.html);

            $line.append($message);

            $channel_div_for(e.channel).append( $line );

            setTimeout(function() {
                $("#channels-wrapper").scrollTop( $("#channels-wrapper").get(0).scrollHeight );
                // $("#channels-wrapper").stop();
                // $("#channels-wrapper").animate({ "scrollTop": $("#channels-wrapper").get(0).scrollHeight });
            }, 300);
        } catch(e) { if (console) console.log(e) };
    }

    setTimeout(function() {
        if (typeof DUI != 'undefined') {
            var s = new DUI.Stream();
            s.listen('application/json', function(payload) {
                onNewEvent(eval('(' + payload + ')'));
            });
            s.load('/irc/mpoll?session=' + Date.now());
        } else {
            $.ev.loop('/irc/poll?session=' + Date.now(), Social.Irc.Handlers);
        }
    }, 500);
});
