module.exports = {
  id: 'jupyter-pwa',
  autoStart: true,
  activate: function(app) {
    console.log('JupyterLab extension Jupyter PWA is activated!');

    var manifest = document.createElement('link');
    manifest.rel = 'manifest';
    manifest.href = '/static/manifest.webmanifest';
    document.head.appendChild(manifest);

    document.head.querySelector('meta[name=viewport]').content =
      'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=0';

    var meta = document.createElement('meta');
    meta.name = 'theme-color';
    meta.content = '#04313c';
    document.head.appendChild(meta);

    var meta = document.createElement('meta');
    meta.name = 'apple-mobile-web-app-capable';
    meta.content = 'yes';
    document.head.appendChild(meta);

    var meta = document.createElement('meta');
    meta.name = 'apple-mobile-web-app-status-bar-style';
    meta.content = 'black';
    document.head.appendChild(meta);
  }
};
