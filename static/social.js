var jQT = new $.jQTouch({
    formSelector: "form#not-used",
    useFastTouch: false,
    cacheGetRequests: false
});

var Social = {};
Social.Irc = {};

function padzero(x) {
    if (x < 10) return "0" + x;
    return x;
};

Social.launch_polling = function() {
    if ($.ev) {
        $.ev.loop('/poll?session=' + Date.now(), Social.Handlers);
    }
    else {
        var s = new DUI.Stream();
        s.listen('application/json', function(payload) {
            var e = eval('(' + payload + ')');
            var f = Social.Handlers[e.type];
            if ($.isFunction(f)) f(e);
        });
        s.load('/mpoll?session=' + Date.now());
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

Social.Twitter = {
    build_status_line: function(e) {
        var type   = "text";
        var name   = e.user.screen_name;

        var $line = $('<div/>').attr({'class': 'line ' + type, 'nick': name, 'type': type});

        var $message = $('<span/>').attr({"class": "message", "type": e.type });
        if (e.text) $message.text(e.text);
        if (e.html) $message.html(e.html);

        $message.find('a').oembed(null, { embedMethod: "append", maxWidth: 320 });

        $line
            .append( $('<span/>').attr({"class": "time", "time": e.time }).text(time_text(e.time)) )
            .append( $('<span/>').addClass('sender').html("<a target=\"_blank\" rel=\"external\" href=\"http://twitter.com/" + name +"\">" + name + "</a>: ") )
            .append($message);

        return $line;
    }
};

Social.Plurk = {
    build_line: function(e) {
        var type   = "text";
        var name   = e.user ? e.user.nick_name : e.owner_id;

        var $line = $('<div/>').attr({'class': 'line ' + type, 'nick': name, 'type': type});

        var $message = $('<span/>').attr({"class": "message", "type": e.type });

        $message.html("<span>" + e.qualifier + "<span>" + e.html);

        $message.find('a').oembed(null, { embedMethod: "append", maxWidth: 320 });

        $line
            .append( $('<span/>').attr({"class": "time", "time": e.time }).text(time_text(e.time)) )
            .append( $('<span/>').addClass('sender').html("<a href=\"http://www.plurk.com/" + name +"\">" + name + "</a>: ") )
            .append($message);

        return $line;
    }
};


Social.Handlers = {
    "twitter_statuses_friends": function(e) {
        var $line = Social.Twitter.build_status_line(e);
        $("#twitter-statuses-friends .messages").prepend( $line );
    },
    "twitter_statuses_mentions": function(e) {
        var $line = Social.Twitter.build_status_line(e);
        $("#twitter-statuses-mentions .messages").prepend( $line );
    },

    "plurk": function(e) {
        var $line = Social.Plurk.build_line(e);
        $("#plurk .messages").prepend( $line );
    },

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
    $("#twitter-button-toggle-all-statuses")
        .bind("click", function() {
            var $this = $(this);
            if ($this.data("showing") == "all") {
                $("#twitter-show-all-statuses-style").remove();
                $this.data("showing", "recent").text("Show all tweets");;
            }
            else {
                $("<style/>")
                    .attr("id", "twitter-show-all-statuses-style")
                    .text("#twitter-statuses-friends .messages .line:nth-child(50) ~ * { display: block; }")
                    .appendTo("head");
                $this.data("showing", "all").text("Show ony recent tweets");
            }
            return false;
        });

    $("form").bind("submit", function() {
        if ($("input[name=text]", this).val().match(/^\s*$/)) return false;

        var self = this;

        $(this).attr("disabled", "disabled");
        $.ajax({
            url: $(this).attr("action"),
            data: $(this).serialize(),
            type: 'post',
            dataType: 'json',
            success: function(r) {
                $(this).removeAttr("disabled");
                $("input[name=text]", self).val("").focus();
            }
        });
        return false;
    });

    if (navigator.userAgent.indexOf("iPhone") != -1) {
        Social.launch_polling();
    }
    else {
        Social.launch_polling();
        // $.getScript("/static/DUI.js", function() {
        //     $.getScript("/static/Stream.js", Social.launch_polling)
        // });
    }
});
