if (navigator.standalone) {
    $("body").addClass("full-screen");
}

if (navigator.userAgent.indexOf("iPhone") != -1) {
    window.onorientationchange = function() {
        if (window.orientation == 0 || window.orientation == 180) {
            $("body").removeClass("landscape");
        }
        else {
            $("body").addClass("landscape");
        }
    };
    window.onorientationchange();
}

function padzero(x) {
    if (x < 10) return "0" + x;
    return x;
};

var Social = {};
Social.Irc = {};

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

    $channel_div_for(e.channel).prepend( $line );

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

        $channel_div_for(e.channel).prepend( $line );
    }
};

$(function() {
    $("#text").focus();

    $("form#irc").bind("submit", function() {
        var text = $("#text").val();

        if (!text) return false;

        $.ajax({
            url: "/irc",
            data: $(this).serialize(),
            type: 'post',
            dataType: 'json',
            success: function(r) {
                $("#text").val("").focus();
            }
        });
        return false;
    });

    $("select[name=channel]").bind("change", function() {
        $("#channels-wrapper .channel").hide();
        $channel_div_for( $(this).val() ).show();
        return false;
    });
    $("select[name=channel]").val( $("select[name=channels] option:first").val() );
    $("select[name=channel]").trigger("change");

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

            $channel_div_for(e.channel).prepend( $line );
        } catch(e) { if (console) console.log(e) };
    }

    setTimeout(function() {
        var s = new DUI.Stream();
        s.listen('application/json', function(payload) {
            var e = eval('(' + payload + ')');
            var f = Social.Irc.Handlers[e.type];
            if ($.isFunction(f)) {
                f(e);
            }
        });
        s.load('/irc/mpoll?session=' + Date.now());
    }, 500);
});
