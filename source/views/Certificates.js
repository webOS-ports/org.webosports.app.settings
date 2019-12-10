enyo.kind({
  name: "CertMgrService",
  kind: "enyo.LunaService",
  service: "palm://org.webosports.service.certmgr"
});

enyo.kind({
    name: "Toast",
    kind: "enyo.Slideable",
    style: "position: absolute;\
        bottom: 54px;\
        width: 90%;\
        margin-left: -45%;\
        left: 50%;\
        height: 33%;\
        color: black;\
        background-color: lightgrey;\
        border: 1px grey;\
        border-radius: 16px 16px 0 0;\
        text-align: center;",
    classes: "onyx-toolbar",
    min: 0,
    max: 100,
    value: 100,
    unit: "%",
    axis: "v",
    draggable: false,
});

enyo.kind({
    name: "GrabberToolbar",
    kind: "onyx.Toolbar",
    components:[
        {kind: "onyx.Grabber"}
    ],
    reflow: function() {
        this.children[0].applyStyle('visibility', enyo.Panels.isScreenNarrow() ? 'hidden' : 'visible');
    }
});

enyo.kind({
  name: "CertificateInfoPanel",
  layoutKind: "FittableRowsLayout",
  components: [
    {kind: "enyo.Scroller", touch: true, horizontal: "hidden", fit: true, components: [
      {name: "div", tag: "div", style: "padding: 35px 10% 35px 10%;", fit: true, components: [
        {kind: "onyx.Groupbox", components: [
          {kind: "onyx.GroupboxHeader", content: "Issuer"},
          { kind: "enyo.FittableColumns", classes: "group-item", components:[
            {kind: "Control", content: "Name", style: "padding-top: 10px;"},
            {kind: "Control", name: "IssuerName", style: "float: right; padding-top: 10px;", content: "Unknown"},
          ]},
          { kind: "enyo.FittableColumns", classes: "group-item", components:[
            {kind: "Control", content: "Organization", style: "padding-top: 10px;"},
            {kind: "Control", name: "IssuerOrganization", style: "float: right; padding-top: 10px;", content: "Unknown"},
          ]},
          { kind: "enyo.FittableColumns", classes: "group-item", components:[
            {kind: "Control", content: "Organization Unit", style: "padding-top: 10px;"},
            {kind: "Control", name: "IssuerOrganizationUnit", style: "float: right; padding-top: 10px;", content: "Unknown"},
          ]},
        ]},
        {kind: "onyx.Groupbox", components: [
          {kind: "onyx.GroupboxHeader", content: "Subject"},
          { kind: "enyo.FittableColumns", classes: "group-item", components:[
            {kind: "Control", content: "Name", style: "padding-top: 10px;"},
            {kind: "Control", name: "SubjectName", style: "float: right; padding-top: 10px;", content: "Unknown"},
          ]},
          { kind: "enyo.FittableColumns", classes: "group-item", components:[
            {kind: "Control", content: "Organization", style: "padding-top: 10px;"},
            {kind: "Control", name: "SubjectOrganization", style: "float: right; padding-top: 10px;", content: "Unknown"},
          ]},
        ]},
        {kind: "onyx.Groupbox", components: [
          {kind: "onyx.GroupboxHeader", content: "Validity"},
          { kind: "enyo.FittableColumns", classes: "group-item", components:[
            {kind: "Control", content: "Issued on", style: "padding-top: 10px;"},
            {kind: "Control", name: "IssuedTime", style: "float: right; padding-top: 10px;", content: "Unknown"},
          ]},
          { kind: "enyo.FittableColumns", classes: "group-item", components:[
            {kind: "Control", content: "Expires on", style: "padding-top: 10px;"},
            {kind: "Control", name: "ExpireTime", style: "float: right; padding-top: 10px;", content: "Unknown"},
          ]},
        ]},
      ]},
    ]},
  ],
  assignCert: function(certificate) {
    this.$.IssuerName.setContent(certificate.issuer);
    this.$.IssuerOrganization.setContent(certificate.issuerOrganization);
    this.$.IssuerOrganizationUnit.setContent(certificate.issuerOrganizationUnit);
    this.$.SubjectName.setContent(certificate.subject);
    this.$.SubjectOrganization.setContent(certificate.subjectOrganization);
    this.$.IssuedTime.setContent(certificate.start);
    this.$.ExpireTime.setContent(certificate.expiration);
  }
});

enyo.kind({
	name: "Certificates",
	layoutKind: "FittableRowsLayout",
  palm: false,
  events: {
    onBackbutton: ""
  },
  components: [
    // UI components
    {name: "CertPicker", kind: "FilePicker", fileType:["document"], onPickFile: "onNewCertForInstallSelected", autoDismiss: true},
    {kind: "onyx.Toolbar", name: "Header", style: "line-height: 28px;", content: "Installed Certificates"},
    {name: "CertPanels", kind: "Panels", arrangerKind: "HFlipArranger", fit: true, draggable: false,components: [
      {name:"CertList", layoutKind: "FittableRowsLayout", components: [
        {kind: "List", name: "certList", classes: "enyo-list", fit: true, touch: true, count: 0, onSetupItem: "setupCertificateItem", components: [
          {classes: "group-item enyo-border-box", layoutKind: "FittableColumnsLayout", style: "margin: 5px;", ontap: "onCertSelected", components: [
            {layoutKind: "FittableRowsLayout", components: [
              {name: "name", style: "margin-left: 10px; font-weight: bolder;", fit: true}
            ]}
          ]},
        ]},
      ]},
      {name: "CertInfo", kind: "CertificateInfoPanel"},
      { /* Workaround for HFlipArranger incorrectly displaying with 2 panels*/ },
    ]},
    {name: "SimpleMessage", kind: "Toast", style: "height: 90px;", components: [
      {name: "SimpleMessageContent",style: "display: block; font-size: 14pt; height: 32px;",allowHtml: true, content: "Message<br>I am a fish."},
      {kind: "onyx.Button", style: "display: block; width: 100%; margin-top: 4px;", content: "Okay", ontap: "hideSimpleMessage"}
    ]},
    {kind: "GrabberToolbar", style: "position: relative;", components: [
      {kind: "onyx.Button", name: "AddCert", classes: "left", content: "Add", ontap: "onAddCert"}
    ]},
    // Service components
    {kind: "CertMgrService", name: "installCertificate", method: "install", onComplete: "onInstallFinished"},
    {kind: "CertMgrService", name: "listCertificates", method: "listAll", onComplete: "onListCertificatesFinished"}
  ],
  // UI handlers
  create: function(inSender, inEvent) {
    this.inherited(arguments);

    this.$.CertPanels.setIndex(0);

    if (!window.PalmSystem) {
      enyo.log("Non-palm platform, service requests disabled.");
      return;
    }

    this.palm = true;
    this.certificates = [];

    this.$.listCertificates.send({});
  },
  setupCertificateItem:  function(inSender, inEvent) {
    var cert = this.certificates[inEvent.index];
    if (cert) {
        this.$.name.setContent(cert.subject);
    }

    return true;
  },
  displaySimpleMessage: function (inMessage) {
      this.$.SimpleMessageContent.setContent(inMessage);
      if (this.$.SimpleMessage.value !== this.$.SimpleMessage.min) {
          this.$.SimpleMessage.animateToMin();
      }
  },
  hideSimpleMessage: function () {
      this.$.SimpleMessage.animateToMax();
  },
  onAddCert: function(inSender, inEvent) {
    this.$.CertPicker.pickFile();
  },
  onNewCertForInstallSelected: function(inSender, inEvent) {
    if(inEvent && inEvent.length == 0)
      return;

    var params = {"path": inEvent[0].fullPath};

    this.$.installCertificate.send(params);
  },
  onCertSelected: function(inSender, inEvent) {
    var cert = this.certificates[inEvent.index];
    this.enterCertInfo(cert);
  },
  enterCertList: function() {
    this.$.Header.setContent("Installed Certificates");
    this.$.CertPanels.setIndex(0);
    this.$.AddCert.show();
  },
  enterCertInfo: function(cert) {
    this.$.AddCert.hide();
    this.$.Header.setContent("Certificate Details");
    this.$.CertInfo.assignCert(cert);
    this.$.CertPanels.setIndex(1);
  },
  handleBackGesture: function(inSender, inEvent) { 
    if (this.$.CertPanels.getIndex() > 0)
      this.enterCertList();
    else
      this.doBackbutton();
  },
  // Service handlers
  onInstallFinished: function(inSender, inResponse) {
    var result = inResponse;

    if (!result.returnValue) {
      this.displaySimpleMessage("Failed to install certificate");
      return;
    }

    this.displaySimpleMessage("Certificate installed!");

    // retrieve all certificates again to have them in our list
    // (there is no subscription support yet)
    this.$.listCertificates.send({});
  },
  onListCertificatesFinished: function(inSender, inResponse) {
    var result = inResponse;

    if (!result.returnValue) {
      this.displaySimpleMessage("Failed to list certificates");
      return;
    }

    this.certificates = result.certificates;
    this.$.certList.setCount(this.certificates.length);
    this.$.certList.reset();
  }
});
