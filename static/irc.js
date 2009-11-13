var jQT = new $.jQTouch();

var Social = {};
Social.Irc = {};

function padzero(x) {
    if (x < 10) return "0" + x;
    return x;
};

Social.launch_polling = function() {
    if ($.ev) {
        $.ev.loop('/irc/poll?session=' + Date.now(), Social.Irc.Handlers);
    }
    else {
        var s = new DUI.Stream();
        s.listen('application/json', function(payload) {
            var e = eval('(' + payload + ')');
            var f = Social.Irc.Handlers[e.type];
            if ($.isFunction(f)) f(e);
        });
        s.load('/irc/mpoll?session=' + Date.now());
    }
}

function time_text(x) {
    var t = new Date( Date.parse(x) );
    var time_text = padzero(t.getHours()) + ":" + padzero(t.getMinutes());
    return time_text;
}

var $channel_div_for = function(channel) {
    var channel_el_id = "channel-" + channel.toLowerCase().replace(/[^0-9a-z]/g, function(s) { return s.toString().charCodeAt(0) });

    return $("#" + channel_el_id);
}

Social.Irc.append_event_line = function(e, message_body) {
    var name   = e.name || e.ident || 'Anonymous';

    var $line = $('<div/>').attr({'class': 'line event', 'nick': name, 'type': e.type});

    var $message = $('<span/>').attr({"class": "message", "type": e.type }).text(message_body);

    $line
        .append( $('<span/>').attr({"class": "time", "time": e.time }).text(time_text(e.time)) )
        .append($message);

    $channel_div_for(e.channel).find(".messages").prepend( $line );
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

        $message.find('a').oembed(null, { embedMethod: "append", maxWidth: 320 });

        $line
            .append( $('<span/>').attr({"class": "time", "time": e.time }).text(time_text(e.time)) )
            .append( $('<span/>').addClass('sender').text(name + ": ") )
            .append($message);

        $channel_div_for(e.channel).find(".messages").prepend( $line );
    }
};

$(function() {
    $(".channel > form").bind("submit", function() {
        var self = this;
        $.ajax({
            url: "/irc",
            data: $(this).serialize(),
            type: 'post',
            dataType: 'json',
            success: function(r) {
                $("input[name=text]", self).val("").focus();
            }
        });
        return false;
    });

    if (navigator.userAgent.indexOf("iPhone") != -1) {
        if (navigator.standalone) {
            $("body").addClass("full-screen");
        }
        $.getScript("/static/jquery.ev.js", Social.launch_polling);
    }
    else {
        $.getScript("/static/DUI.js", function() {
            $.getScript("/static/Stream.js", Social.launch_polling)
        });
    }

    setTimeout(function() {
        jQT.goTo("#" + $(".channel:first").attr("id"), "cube" );
    }, 3000);

    $(".channel h1").bind("click", function(e) {
        var n = $(".channel.current").next();
        if (n.size() == 0)
            n = $(".channel:first")
        jQT.goTo("#" + n.attr("id"), "cube" );
    });
});
