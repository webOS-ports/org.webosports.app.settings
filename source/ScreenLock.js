enyo.kind({
	name: "ScreenLock",
	layoutKind: "FittableRowsLayout",
	style: "background-color: #EAEAEA;",
	components:[
		{kind: "onyx.Toolbar",
		components:[
				{content: "Screen & Lock"},
		]},
		{kind: "Scroller",
		touch: true,
		horizontal: "hidden",
		fit: true,
		components:[
			{tag: "div", style: "padding: 35px 10% 35px 10%;", components: [
				{kind: "onyx.Groupbox", components: [
					{kind: "onyx.GroupboxHeader", content: "Screen"},
					{classes: "group-item",
					components:[
						{content: "Brightness"},
						{kind: "onyx.Slider"}
					]},
					{classes: "group-item",
					style: "height: 42px;",
					components:[
						{content: "Turn off after",
						fit: true,
						style: "display: inline-block; line-height: 42px;"},
						{kind: "onyx.PickerDecorator", style: "float: right;", components: [
							{},
							{kind: "onyx.Picker", components: [
								{content: "30 Seconds", active: true},
								{content: "1 Minute"},
								{content: "2 Minutes"},
								{content: "3 Minutes"}
							]}
						]}
					
					]},
				]},
				{kind: "onyx.Groupbox", components: [
					{kind: "onyx.GroupboxHeader", content: "Wallpaper"},
					{classes: "group-item",
					components:[
						{kind: "onyx.Button", fit: true, content: "Change Wallpaper"}
					
					]},
				]},
				{kind: "onyx.Groupbox", components: [
					{kind: "onyx.GroupboxHeader", content: "Advanced Gestures"},
					{classes: "group-item",
					components:[
						{kind: "onyx.TooltipDecorator", components: [
							{kind: "Control",
							content: "Switch Applications",
							style: "display: inline-block; line-height: 32px;"},
							{kind: "onyx.ToggleButton", style: "float: right;"},
							{kind: "onyx.Tooltip",
							content: "Swiping from the right or left edge of the gesture area will switch to the next or previous app."}
						]},
					
					]},
				]},
				{kind: "onyx.Groupbox", components: [
					{kind: "onyx.GroupboxHeader", content: "Notifications"},
					{classes: "group-item",
					components:[
						{kind: "Control",
						content: "Show When Locked",
						style: "display: inline-block; line-height: 32px;"},
						{kind: "onyx.ToggleButton", style: "float: right;"},
					]},
					{classes: "group-item",
					components:[
						{kind: "onyx.TooltipDecorator", components: [
							{kind: "Control",
							content: "Blink Notifications",
							style: "display: inline-block; line-height: 32px;"},
							{kind: "onyx.ToggleButton", style: "float: right;"},
							{kind: "onyx.Tooltip", content: "Blinks the LED when new notifications arrive."}
						]},
					]},
				]},
				{kind: "onyx.Groupbox", components: [
					{kind: "onyx.GroupboxHeader", content: "Voice Dialing"},
					{classes: "group-item",
					components:[
						{kind: "onyx.TooltipDecorator", components: [
							{kind: "Control",
							content: "Enable When Locked",
							style: "display: inline-block; line-height: 32px;"},
							{kind: "onyx.ToggleButton", style: "float: right;"},
							{kind: "onyx.Tooltip", content: "Access voice dialing even when your phone is locked."}
						]}
					]},
				]},
			]},
		]}
	]
});
