var time_text_memoized = {};
function time_text(x) {
    if (time_text_memoized[x]) return time_text_memoized[x];
    var t = (typeof x == "string") ? new Date( Date.parse(x) ) : x;
    var h = t.getHours();
    var m = t.getMinutes();
    time_text_memoized[x] = (h < 10 ? "0" + h : h) + ":" + (m < 10 ? "0" + m : m);
    return time_text_memoized[x];
}

var Social = {};

Social.Irc = {};

Social.launch_polling = function() {
    if (typeof DUI == "undefined") {
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

Social.Irc = {
    channel_div_for: function(channel) {
        var channel_el_id = "channel-" + channel.toLowerCase().replace(/[^0-9a-z]/g, function(s) { return s.toString().charCodeAt(0) });
        return $("#" + channel_el_id);
    },

    build_line: function(e) {
        var name   = e.name;

        var lineClassName = "text";
        var messageClassName = "privmsg";

        if (e.type == "irc_ctcp_action") {
            messageClassName = "notice"
        }

        var $line = $('<div/>').attr({'class': 'line ' + lineClassName, 'nick': name, 'type': messageClassName, "source": "irc"});

        var $message = $('<span/>').attr({"class": "message", "type": messageClassName });
        if (e.text) $message.text(e.text);
        if (e.html) $message.html(e.html);

        $message.find('a').oembed(null, { embedMethod: "append", maxWidth: 320 });

        $line
            .append( $('<span/>').attr({"class": "time", "time": e.time }).text(time_text(e.time)) )
            .append( $('<span/>').addClass('sender').text(name + ": ") )
            .append($message);

        return $line;
    },

    append_event_line: function(e, message_body) {
        var name   = e.name;

        var $line = $('<div/>').attr({'class': 'line event', 'nick': name, 'type': e.type, "source": "irc"});

        var $message = $('<span/>').attr({"class": "message", "type": e.type }).text(message_body);

        $line
            .append( $('<span/>').attr({"class": "time", "time": e.time }).text(time_text(e.time)) )
            .append($message);

        Social.Irc.channel_div_for(e.channel).find(".messages").prepend( $line );
        return $line;
    },

    append_line_to_channel_quicklook: function(channel, $line) {
        var $channel_quicklook = $("a[href=#" + Social.Irc.channel_div_for(channel).attr("id") + "] ~ .messages");
        $channel_quicklook.prepend($line.clone());
        $channel_quicklook.find(".line:nth-child(4)").remove();
    }
}

Social.Twitter = {
    build_status_line: function(e) {
        var created_at = new Date( Date.parse(e.created_at) );

        var type   = "text";
        var name   = e.user.screen_name;

        var $line = $('<div/>').attr({
            'class': 'line ' + type,
            'nick': name,
            'type': type,
            "source": "twitter",
            "id": "twitter-status-" + e.id
        });

        var $message = $('<span/>').attr({"class": "message", "type": e.type });
        if (e.text) $message.text(e.text);
        if (e.html) $message.html(e.html);

        $message.find('a').oembed(null, { embedMethod: "append", maxWidth: 320 });

        $line
            .append( $('<span/>').attr({"class": "time", "time": e.time }).text(time_text(created_at)) )
            .append( $('<span/>').addClass('sender').html("<a target=\"_blank\" rel=\"external\" href=\"http://twitter.com/" + name +"\">" + name + "</a>: ") )
            .append($message);

        return $line;
    }
};

Social.Plurk = {
    build_line: function(e) {
        var type   = "text";
        var name   = e.owner ? e.owner.nick_name : e.owner_id;

        var $line = $('<div/>').attr({'class': 'line ' + type, 'nick': name, 'type': type, "source": "plurk"});

        var $message = $('<span/>').attr({"class": "message", "type": e.type });

        $message.html("<span>" + e.qualifier + "<span>" + e.html);

        $message.find('a').oembed(null, { embedMethod: "append", maxWidth: 320 });

        $line
            .append( $('<span/>').attr({"class": "response_count"}).text( e.response_count ) )
            .append( $('<span/>').attr({"class": "time", "time": e.time }).text(time_text(e.time)) )
            .append( $('<span/>').addClass('sender').html("<a target=\"_blank\" href=\"http://www.plurk.com/" + name +"\">" + name + "</a>: ") )
            .append($message);

        var plurk_page_uri = "http://plurk.com/m/p/" + parseInt(e.plurk_id).toString(36);
        $line.bind("click", function() {
            window.open(plurk_page_uri)
            return false;
        });

        return $line;
    }
};

Social.Dashboard = {
    prepend_line: function($line) {
        if ($("#dashboard .messages .line").size() == 7) {
            $("#dashboard .messages .line:last-child").remove();
        }
        $("#dashboard .messages").prepend( $line );
    }
};
Social.rTorrent= {
    build_line: function(e) {
        var created_at = new Date( Date.parse(e.created_at) );

        var type   = "text";
        var name   = e.name;

        var $line = $('<div/>').attr({
            'class': 'line ' + type,
            'type': type,
            "source": "rtorrent",
            "id": "rtorrent-" + e.hash
        });

        var $message = $('<span/>').attr({"class": "message", "type": e.type });
        $line
            .append($('<span/>').attr({"class": "message", "type": e.type }).text(e.name))
            .append($('<span/>').attr({"class": "percent" }).text(e.percent))
            .append($('<span/>').attr({"class": "rate"}).text(e.human_up_rate))
            .append($('<span/>').attr({"class": "rate"}).text(e.human_down_rate));
        if(e.is_active=="1"){
           $line.append($('<a/>').attr({"class": "cmd","type":"stop","href":"#"}).text('stop'));
        }else{
           $line.append($('<a/>').attr({"class": "cmd","type":"start","href":"#"}).text('start'));
        }
           $line.append($('<a/>').attr({"class": "cmd","type":"erase","href":"#"}).text('remove'));

        return $line;
    }
}
Social.Handlers = {
    "twitter_statuses_friends": function(e) {
        var $line = Social.Twitter.build_status_line(e);
        $("#twitter-statuses-friends .messages").prepend( $line );

        Social.Dashboard.prepend_line($line.clone());
    },
    "twitter_statuses_mentions": function(e) {
        var $line = Social.Twitter.build_status_line(e);
        $("#twitter-statuses-mentions .messages").prepend( $line );

        Social.Dashboard.prepend_line($line.clone());
    },

    "plurk": function(e) {
        var $line = Social.Plurk.build_line(e);
        $("#plurk .messages").prepend( $line );

        Social.Dashboard.prepend_line($line.clone());
    },

    "irc_join": function(e) {
        var name   = e.name;
        Social.Irc.append_event_line(e, name + " has joined " + e.channel);
    },

    "irc_part": function(e) {
        var name   = e.name;
        Social.Irc.append_event_line(e, name + " has parted " + e.channel);
    },

    "irc_quit": function(e) {
        var name   = e.name;
        Social.Irc.append_event_line(e, name + " has quit " + e.channel);
    },

    "irc_privmsg": function(e) {
        var $line = Social.Irc.build_line(e);
        Social.Irc.channel_div_for(e.channel).find(".messages").prepend( $line );

        var $line2 = $line.clone();

        $line2.prepend($("<span />").addClass("channel").text(e.channel));

        $line2.bind("click", function() {
            $("a[href=#" + Social.Irc.channel_div_for(e.channel).attr("id") + "]").trigger("click");
        });

        Social.Dashboard.prepend_line($line2);

        Social.Irc.append_line_to_channel_quicklook(e.channel, $line);
    },

    "irc_ctcp_action": function(e) {
        var $line = Social.Irc.build_line(e);
        Social.Irc.channel_div_for(e.channel).find(".messages").prepend( $line );
        Social.Irc.append_line_to_channel_quicklook(e.channel, $line);
    },
    "rtorrent_status": function(e) {
        var $line = Social.rTorrent.build_line(e);
        $("#"+$line.attr('id')).remove();
        $("#rtorrent .messages").prepend( $line );
    },
    "rtorrent_remove_torrent": function(e) {
        $("#rtorrent-"+e.hash).remove();
    }
};

$(function() {
    (function() {
        location.hash = "";
        $("body > *").css("display", "none");
        $("body > *:first").addClass("current");

        $(window).load(function() { setTimeout(function() { window.scrollTo(0, 1); }, 10); });

        $("body").bind("orientationchange", function() {
            orientation = window.innerWidth < window.innerHeight ? 'profile' : 'landscape';
            $(body).removeClass('profile landscape').addClass(orientation);
        });

        $("a").live("click", function() {
            var href = $(this).attr("href");
            if ( href.match(/^#\S+$/) ) {
                if ( !$(this).is(".backButton") )
                    $(this).addClass("active");

                $(':focus').blur();
                window.scrollTo(0, 0);

                var $from = $("body > .current");
                var $to   = $(href);

                var reverse = $(this).is(".toolbar > .back") ? " reverse" : "";
                var effect  = " " + ($(this).attr("effect") || "slide");

                $to.one("webkitAnimationEnd", function() {
                    $(".active").removeClass("active");

                    $from.removeClass("out current" + effect + reverse);
                    $to.removeClass("in" + effect + reverse);
                }).addClass("current in" + effect + reverse);

                $from.addClass("out" + effect + reverse);

                return false;
            }
            return true;
        });
    })();

    $(".button.toggle-all-messages")
        .bind("click", function() {
            var $this = $(this);
            var x = $this.text();

            var page_id = $this.parents("body > *").attr("id");

            if ($this.data("showing") == "all") {
                $("#" + page_id + "-style").remove();
                x = x.replace("only recent", "all");
                $this.data("showing", "recent").text(x);
            }
            else {
                $("<style/>")
                    .attr("id", page_id + "-style")
                    .text("#" + page_id + " .messages .line:nth-child(50) ~ * { display: block; }")
                    .appendTo("head");

                x = x.replace("all", "only recent");
                $this.data("showing", "all").text(x);
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

    $("#rtorrent a.cmd").live("click", function() {
        var self = this;
        if($(this).attr('type')=='erase' && !confirm('remove torrent?')){
            return false;
        }
        $.ajax({
            url: '/rtorrent',
            data: "cmd=d."+$(this).attr("type")+"&id="+this.parentNode.id.split(/-/)[1],
            type: 'post',
            dataType: 'json',
            success: function(r) {
            }
        });
        return false;
    });
    if (navigator.userAgent.match(/(Mobile Safari|iPhone)/)) {
        Social.launch_polling();
    }
    else {
        $.getScript("/static/DUI.js", function() {
            $.getScript("/static/Stream.js", Social.launch_polling)
        });
    }
});
