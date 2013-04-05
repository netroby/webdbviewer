use 5.008007;
package Webdbviewer;
use Mojo::Base 'Mojolicious';
use Carp 'croak';

our $VERSION = '0.01';

sub startup {
  my $self = shift;
  
  # Config
  $self->plugin('INIConfig', {ext => 'conf'});
  
  # My Config(Development)
  my $my_conf_file = $self->home->rel_file('webdbviewer.my.conf');
  $self->plugin('INIConfig', {file => $my_conf_file}) if -f $my_conf_file;
  
  # Server Config
  my $conf = $self->config;
  $conf->{hypnotoad} ||= {listen => ["http://*:10030"]};
  my $listen = $conf->{hypnotoad}{listen} || '';
  if ($listen ne '' && ref $listen ne 'ARRAY') {
    $listen = [ split /,/, $listen ];
  }
  $conf->{hypnotoad}{listen} = $listen;
  
  # Database Config
  my $dbtype = $conf->{basic}{dbtype} || '';
  my $dbname = $conf->{basic}{dbname} || '';
  my $user = $conf->{basic}{user};
  my $password = $conf->{basic}{password};
  my $host = $conf->{basic}{host};
  my $port = $conf->{basic}{port};
  my $site_title = $conf->{basic}{site_title} || 'Web DB Viewer';
  
  my $dsn;
  if ($dbtype eq 'sqlite') {
    $dsn = "dbi:SQLite:dbname=$dbname";
  }
  elsif ($dbtype eq 'mysql') {
    $dsn = "dbi:mysql:database=$dbname";
    $dsn .= ";host=$host" if defined $host && length $host;
    $dsn .= ";port=$port" if defined $host && length $host;
  }
  else {
    my $error = "Error in configuration file: [basic]dbtype ($dbtype) is not supported";
    $self->log->error($error);
    croak $error;
  }
  
  # Load DBViewer plugin
  eval {
    $self->plugin(
      'DBViewer',
      dsn => $dsn,
      user => $user,
      password => $password,
      prefix => '',
      site_title => $site_title
    );
  };
  if ($@) {
    $self->log->error($@);
    croak $@;
  }
  
  # Reverse proxy support
  $ENV{MOJO_REVERSE_PROXY} = 1;
  $self->hook('before_dispatch' => sub {
    my $self = shift;
    
    if ( $self->req->headers->header('X-Forwarded-Host')) {
        my $prefix = shift @{$self->req->url->path->parts};
        push @{$self->req->url->base->path->parts}, $prefix;
    }
  });
}

1;