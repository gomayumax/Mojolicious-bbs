#!/usr/bin/env perl
use Mojolicious::Lite;
use DBI;
use Data::Dumper;
use Mojolicious::Sessions;

# Documentation browser under "/perldoc"
plugin 'PODRenderer';

my $user = 'root'; # MySQLのユーザ名
my $pass = ''; # MySQLのパスワード
my $database = 'perl-bbs'; # 使用するデータベース名
my $hostname = 'localhost'; # データベースサーバのアドレス
my $port = ''; # データベースサーバに接続する時のポート番号
my $table =  'posts'; # 操作するテーブル名
my $user_table =  'users'; # 操作するテーブル名

my $sessions = Mojolicious::Sessions->new;

get '/login' => sub {
    my $c = shift;
    $c->render('login');
};

post '/login' => sub {
    my $c = shift;
    my $name = $c->param('name');
    my $passwd = $c->param('passwd');

    # データベースへ接続
    my $db = DBI->connect(
      "DBI:mysql:$database:$hostname:$port",
      $user,
      $pass
    ) or die "cannot connect to MySWL: $DBI::errstr";

    my $sql  = "select * from ".$user_table. " where name = ? and passwd = ?";
     
    # $sqlの実行準備
    my $sth = $db->prepare($sql);
    # SQL実行
    $sth->execute(($name, $passwd));

    my $login_success = $sth->fetchrow_arrayref;

    # SQL文を開放
    $sth->finish;

    # データベースから切断   
    $db->disconnect;

    if($login_success) {
      $c->session->{id} = $login_success->[0];
      $c->session->{name} = $login_success->[1];
      $c->redirect_to('/');
    } else {
        $c->render('login');
    }

};


get '/' => sub {
    my $c = shift;

    if (!($c->session('id') && $c->session('name'))) {
      $c->redirect_to('/login');
    }

    # データベースへ接続
    my $db = DBI->connect(
      "DBI:mysql:$database:$hostname:$port",
      $user,
      $pass
    ) or die "cannot connect to MySWL: $DBI::errstr";

    my $sql  = "select `p`.* , `u`.name from posts as `p` JOIN `users` AS `u` ON `u`.`id` = `p`.`user_id`";
     
    # $sqlの実行準備
    my $sth = $db->prepare($sql);

    # SQL実行
    $sth->execute;

    my @posts = ();
    # fetchrow_arrayを使って行データを項目の配列として取り出す
    while (my $line = $sth->fetchrow_arrayref) {
      my ($id, $post, $user_id, $created_at, $updated_at, $deleted_at, $user_name) = @$line;
      my %post = (id => $id, post => $post, user_name => $user_name);
      unshift @posts, \%post;
    }

    # SQL文を開放
    $sth->finish;

    # データベースから切断   
    $db->disconnect;

    # テンプレートに変数を展開して表示します
    $c->stash(posts => \@posts);
    $c->stash(name => $c->session('name'));
    $c->render('index');
};

post '/post' => sub {
    my $c = shift;
    my $post = $c->param('post');
    # データベースへ接続
    my $db = DBI->connect(
      "DBI:mysql:$database:$hostname:$port",
      $user,
      $pass
    ) or die "cannot connect to MySWL: $DBI::errstr";

    my $sql  = "insert into $table (post, user_id) values (?, ?)";
     
    # $sqlの実行準備
    my $sth = $db->prepare($sql);

    # SQL実行
    $sth->execute(($post, $c->session('id')));

    # SQL文を開放
    $sth->finish;

    # データベースから切断   
    $db->disconnect;

    $c->redirect_to('/');
};

get '/logout' => sub {
  my $c = shift;
  $c->session(expires => 1);

  $c->redirect_to('/login');
};

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
%= form_for '/post' => method => 'POST' => begin
    %= text_field 'post'
    %= submit_button '投稿する'
% end

<table class="table">
  <thead>
    <tr>
        <th>id</th>
        <th>post</th>
        <th>user_id</th>
    </tr>
  </thead>
  <tbody>
% for my $post (@$posts) {
    <tr>
        <td><%= $post->{id} %></td>
        <td><%= $post->{post} %></td>
        <td><%= $post->{user_name} %></td>
    </tr>
% }
    </tbody>
</table>

@@ login.html.ep
% layout 'default';
% title 'login';
%= form_for '/login' => method => 'POST' => begin
    name:
    %= text_field 'name'
    <br>
    pass:
    %= text_field 'passwd'
    <br>
    %= submit_button 'login'
% end

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title><%= title %></title>
    <!-- Latest compiled and minified CSS -->
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css" integrity="sha384-BVYiiSIFeK1dGmJRAkycuHAHRg32OmUcww7on3RYdg4Va+PmSTsz/K68vbdEjh4u" crossorigin="anonymous">

    <!-- Optional theme -->
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap-theme.min.css" integrity="sha384-rHyoN1iRsVXV4nD0JutlnGaslCJuC7uwjduW9SVrLvRYooPp2bWYgmgJQIXwl/Sp" crossorigin="anonymous">

    <!-- Latest compiled and minified JavaScript -->
    <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js" integrity="sha384-Tc5IQib027qvyjSMfHjOMaLkfuWVxZxUPnCJA7l2mCWNIpG9mGCD8wGNIcPD7Txa" crossorigin="anonymous"></script>
  </head>
  <body>
  welcome to <%= $name %>
  <br>
  <a href="/logout">logout</a>
    <%= content %>
  </body>
</html>



