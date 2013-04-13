enyo.kind({
	name: "DevOptions",
	layoutKind: "FittableRowsLayout",
	palm: false,
	components:[
		{kind: "Signals", ondeviceready: "deviceready"},
		{
			kind: "onyx.Toolbar",
			style: "line-height: 36px;",
			components:[
				{ content: "Developer Options" },
			]
		},
		{
			kind: "Scroller",
			touch: true,
			horizontal: "hidden",
			fit: true,
			components: [
				{tag: "div", style: "padding: 35px 10% 35px 10%;", components: [
					{kind: "onyx.Groupbox", components: [
						{kind: "onyx.GroupboxHeader", content: "Graphics"},
						{classes: "group-item", components:[
							{kind: "Control", content: "Enable FPS counter", style: "display: inline-block; line-height: 32px;"},
							{name: "FpsCounterToggle", kind: "onyx.ToggleButton", style: "float: right;", onChange: "fpsCounterChanged"},
						]}
					]}
				]}
			]
		},
	],
	create: function(inSender, inEvent) {
		this.inherited(arguments);
		if(!window.PalmSystem)
			enyo.log("Non-palm platform, service requests disabled.");
	},
	deviceready: function(inSender, inEvent) {
		this.inherited(arguments);
		this.palm = true;
	},
	fpsCounterChanged: function (inSender, inEvent) {
		var request = navigator.service.Request("luna://com.palm.systemmanager",
		{
			method: 'enableFpsCounter',
			parameters: { "enable": inEvent.value }
		});
	}
});
