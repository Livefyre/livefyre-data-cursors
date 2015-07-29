var Growl = React.createClass({
    getInitialState: function () {
        this.props.stream.on('readable', this.poll.bind(this));
        return {
            locked: false,
            disabled: false,
            minimized: false,
            displayed: [],
            counter: 0,
            count: this.props.stream.count()
        }
    },

    tick: function () {
        var open = this.props.maxItems - this.state.displayed.length;
        var counter = this.state.counter + 1;
        var stream = this.props.stream;
        if (open == 0 || this.state.locked) {
            // tick so that we rerender
            this.setState({
                counter: counter,
                count: stream.count() + this.state.displayed.length
            });
            return;
        }
        var items = stream.read({size: open});
        for (var i = 0; i < items.length; i++) {
            counter += 1;
            this.state.displayed.push([items[i], counter]);
        }
        this.setState({
            counter: counter,
            displayed: this.state.displayed
        });
        if (this.state.displayed.length && !this.gc) {
            this.rescheduleNextGC();
        }
    },

    rescheduleNextGC: function () {
        if (this.gc) {
            clearTimeout(this.gc);
        }
        this.gc = setTimeout(function () {
            this.gc = null;
            this.pop();
        }.bind(this), this.props.tickDuration);
    },

    pop: function () {
        if (!this.state.locked) {
            this.state.displayed.shift();
            this.setState({
                displayed: this.state.displayed
            });
        }
        //reschedule in anycase.
        if (this.state.displayed.length) {
            this.rescheduleNextGC();
        }
    },

    lock: function (toggle) {
        this.setState({locked: toggle});
        // on unlock, look for more data.
        if (toggle == false) {
            this.tick();
        }
    },

    dismiss: function () {
        this.props.stream.close();
        this.setState({disabled: true});
    },

    render: function () {
        if (this.state.disabled) {
            return (<div />);
        }
        var s = this.props.stream;
        var live = s.isLive();
        var displayed = this.state.displayed;
        var count = s.count() + displayed.length;
        return (
            <div>
                {displayed.map(function(item, i) {
                    return (
                        <GrowlNotification key={i} item={item} lock={this.lock.bind(this)} />
                    );
                }, this)}
                <GrowlCount count={count} live={live} />
                <button onClick={this.dismiss.bind(this)} />
            </div>
        );
    }
});

var GrowlCount = React.createClass({
    render: function () {
        return (<span>{this.props.count}</span>);
    }
});

var GrowlNotification = React.createClass({
    render: function () {

    }
});