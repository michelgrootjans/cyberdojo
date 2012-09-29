/*jsl:option explicit*/

var cyberDojo = (function($cd, $j) {

  $cd.sourcePopup = function() {

    var github =
      $cd.divPanel(
        'The cyber-dojo rails server is open source and ' +
        '<a href="https://github.com/JonJagger/cyberdojo/blob/master/readme.txt">' +
        'lives on github' +
        '</a>. ' +
        'You will still need to install compilers for any languages (eg Java) ' +
        'you wish to practice.'
      );

    var ova =
      $cd.divPanel(
        'Alternatively, you can run your own cyber-dojo server using this 817MB ' +
        '<a href="http://dl.dropbox.com/u/11033193/CyberDojo/Turnkey-CyberDojo-20120515.ova">ova image file</a> ' +
        'which has all the language compilers installed. ' +
        'It was built from ' +
        '<a href="http://www.turnkeylinux.org/">TurnKey Linux</a> ' +
        'and runs in ' +
        '<a href="http://www.virtualbox.org/">VirtualBox</a>. ' +
        "You'll want to read the " +
        '<a href="https://github.com/JonJagger/cyberdojo/blob/master/readme.txt">' +
        'github readme.txt' +
        '</a>.'
      );

    var turnKey =
      $cd.divPanel(
        'You can also build your own Turnkey Linux server from scratch using ' +
        '<a href="http://jonjagger.blogspot.co.uk/2012/05/building-rails-3-turnkey-image.html">' +
        'these instructions' +
        '</a>.'
      );

    var grid = $j($cd.makeTable(github,ova,turnKey));
      
    $cd.dialogPopup(grid.html(), 720, 'source');
  };

  return $cd;
})(cyberDojo || {}, $);


