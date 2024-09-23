module.exports = {
  id: 'jupyter-pwa',
  autoStart: true,
  activate: function(app) {
    console.log('JupyterLab extension Jupyter PWA is activated!');
    var manifest = document.createElement('link');
    manifest.rel = 'manifest';
    manifest.href = '/static/manifest.webmanifest';
    document.head.appendChild(manifest);
    console.log('Manifest link added');
  }
};
