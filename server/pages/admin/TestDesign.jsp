<%@include file="CoreImport.jsp_inc" %>

<%--
    TestDesign.jsp
    Static showcase of the admin-console UI widgets defined in
    /u/admin/*.css. No Java logic: this page exists only to
    review and iterate on the design before migrating the real admin pages
    off the Majestic theme.
--%>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>WebWidgets Admin - Design Test</title>

  <link rel="icon" type="image/x-icon" href="/myimages/WWIO_B.png">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.1.1/css/all.min.css">

  <link rel="stylesheet" href="/u/admin/AdminBase.css">
  <link rel="stylesheet" href="/u/admin/AdminLayout.css">
  <link rel="stylesheet" href="/u/admin/AdminWidgets.css">
</head>
<body>

  <!-- ============ Top bar (replaces AdminNavBar.jsp_inc) ============ -->
  <header class="admin-topbar">
    <a class="admin-brand" href="/">
      <img src="/myimages/WWIO_B.png" alt="">
      <span>WebWidgets Admin</span>
    </a>
    <div class="admin-topbar-right">
      <span><i class="fa-solid fa-user"></i> demouser</span>
      <a href="/u/admin/LogOut">Log out</a>
    </div>
  </header>

  <div class="admin-shell">

    <!-- ============ Sidebar (replaces MajesticNavBar.jsp_inc) ============ -->
    <nav class="admin-sidebar">
      <ul>
        <li><a href="#"><i class="fa-solid fa-house"></i>User Home</a></li>
        <li><a href="/u/admin/AdminMain"><i class="fa-solid fa-crown"></i>Admin Main</a></li>
        <li><a href="/u/docs/JsFileDoc"><i class="fa-solid fa-file-lines"></i>Tech Docs</a></li>

        <li class="nav-section">Account</li>
        <li><a href="/u/admin/LogIn"><i class="fa-solid fa-right-to-bracket"></i>Log-In/Out</a></li>
        <li><a href="/u/admin/AccountSetting"><i class="fa-solid fa-gear"></i>Account Settings</a></li>
        <li><a href="/u/admin/ChangePass"><i class="fa-solid fa-key"></i>Change Password</a></li>

        <li class="nav-section">Widgets</li>
        <li><a href="/u/admin/GroupControl"><i class="fa-solid fa-users"></i>Manage Groups</a></li>
        <li><a href="/u/admin/PermissionControl"><i class="fa-solid fa-lock"></i>Permission Control</a></li>
        <li><a href="/u/admin/TemplateGenerator"><i class="fa-solid fa-clone"></i>Template Generator</a></li>
        <li><a href="/u/admin/ImportWidget"><i class="fa-solid fa-file-import"></i>Import Widget</a></li>
        <li><a href="/u/admin/SchemaViewer"><i class="fa-solid fa-database"></i>Schema Viewer</a></li>

        <li class="nav-section">System</li>
        <li><a href="/u/admin/MailRunner"><i class="fa-solid fa-envelope"></i>Email Manager</a></li>
        <li><a href="/u/admin/GetConfig"><i class="fa-solid fa-download"></i>Download Config</a></li>
        <li><a href="/u/admin/TestDesign" aria-current="page"><i class="fa-solid fa-palette"></i>Design Test</a></li>
      </ul>
    </nav>

    <main class="admin-main">

      <!-- ============ Page header ============ -->
      <div class="page-header">
        <h2>Welcome demouser</h2>
        <p>Design test page: every widget the admin console uses, on one screen.</p>
      </div>

      <!-- ============ Server messages ============ -->
      <section class="card">
        <div class="card-body stack">
          <p class="card-title">Server Messages</p>
          <div class="alert alert-info"><i class="fa-solid fa-circle-info"></i>
            <p>Info: replaces the "Message" card at the top of ChangePass, PermissionControl, etc.</p></div>
          <div class="alert alert-success"><i class="fa-solid fa-circle-check"></i>
            <p>Password changed successfully.</p></div>
          <div class="alert alert-warning"><i class="fa-solid fa-triangle-exclamation"></i>
            <p>This can only be entered on a secure connection.</p></div>
          <div class="alert alert-danger"><i class="fa-solid fa-circle-xmark"></i>
            <p>Old password entered incorrectly, please try again.</p></div>
        </div>
      </section>

      <!-- ============ Buttons ============ -->
      <section class="card">
        <div class="card-body">
          <p class="card-title">Buttons</p>
          <div class="btn-row">
            <button class="btn btn-primary">Submit</button>
            <button class="btn">Secondary</button>
            <button class="btn btn-danger"><i class="fa-solid fa-trash"></i>Delete</button>
            <button class="btn btn-primary" disabled>Disabled</button>
            <button class="btn btn-sm btn-primary"><i class="fa-solid fa-plus"></i>Read</button>
            <button class="btn btn-sm"><i class="fa-solid fa-plus"></i>Write</button>
            <button>Unclassed &lt;button&gt;</button>
          </div>
          <hr>
          <p class="muted">Centered row (<code>.btn-row.center</code>), as on PermissionControl:</p>
          <div class="btn-row center">
            <button class="btn btn-primary">+Read</button>
            <button class="btn btn-primary">+Write</button>
          </div>
        </div>
      </section>

      <!-- ============ Forms ============ -->
      <div class="card-grid">
        <section class="card">
          <div class="card-body">
            <p class="card-title">Change Password (stacked form)</p>
            <form onsubmit="return false">
              <div class="form-group">
                <label for="current_pass">Old Password</label>
                <input type="password" id="current_pass" name="current_pass">
              </div>
              <div class="form-group">
                <label for="new1x_pass">New Password</label>
                <input type="password" id="new1x_pass" name="new1x_pass">
              </div>
              <div class="form-group">
                <label for="new2x_pass">Confirm New</label>
                <input type="password" id="new2x_pass" name="new2x_pass">
                <span class="hint">Must match the new password exactly.</span>
              </div>
              <button class="btn btn-primary">Submit</button>
            </form>
          </div>
        </section>

        <section class="card">
          <div class="card-body">
            <p class="card-title">Other Inputs</p>
            <div class="form-group">
              <label for="email">Email</label>
              <input type="email" id="email" placeholder="username@emailservice.com">
            </div>
            <div class="form-group">
              <label for="disabled_in">Disabled</label>
              <input type="text" id="disabled_in" value="Cannot edit" disabled>
            </div>
            <div class="form-group">
              <label for="notes">Textarea</label>
              <textarea id="notes" placeholder="Paste config here..."></textarea>
            </div>
            <label class="form-check"><input type="checkbox" checked> Public read</label>
            <label class="form-check"><input type="radio" name="perm" checked> Read</label>
            <label class="form-check"><input type="radio" name="perm"> Write</label>
          </div>
        </section>
      </div>

      <!-- ============ Inline form / selector ============ -->
      <section class="card">
        <div class="card-body">
          <p class="card-title">Inline Selector (PermissionControl, TemplateGenerator)</p>
          <div class="form-inline">
            <div class="form-group">
              <label for="widget_selector">Widget:</label>
              <select id="widget_selector" name="widget_selector">
                <option>dayplan</option>
                <option selected>links</option>
                <option>mroutine</option>
              </select>
            </div>
            <button class="btn">Go</button>
          </div>
        </div>
      </section>

      <!-- ============ Main table with header action ============ -->
      <section class="card">
        <div class="card-body">
          <div class="card-header">
            <p class="card-title">Widget Listing</p>
            <button class="btn btn-primary"><i class="fa-solid fa-plus"></i>New Widget</button>
          </div>
          <div class="table-wrap">
            <table class="table">
              <thead>
                <tr><th>Name</th><th class="num">#Tables</th><th class="num">Size</th><th class="actions"></th></tr>
              </thead>
              <tbody>
                <tr>
                  <td><b>dayplan</b></td><td class="num">4</td><td class="num">212 Kb</td>
                  <td class="actions">
                    <a class="icon-action" href="#" title="Open"><i class="fa-solid fa-link"></i></a>
                    <a class="icon-action danger" href="#" title="Delete"><i class="fa-solid fa-trash"></i></a>
                  </td>
                </tr>
                <tr>
                  <td><b>links</b></td><td class="num">2</td><td class="num">38 Kb</td>
                  <td class="actions">
                    <a class="icon-action" href="#" title="Open"><i class="fa-solid fa-link"></i></a>
                    <a class="icon-action danger" href="#" title="Delete"><i class="fa-solid fa-trash"></i></a>
                  </td>
                </tr>
                <tr>
                  <td><b>mroutine</b></td><td class="num">7</td><td class="num">3 Mb</td>
                  <td class="actions">
                    <a class="icon-action" href="#" title="Download"><i class="fa-solid fa-download"></i></a>
                    <a class="icon-action danger" href="#" title="Delete"><i class="fa-solid fa-trash"></i></a>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </section>

      <!-- ============ Permission table with badges, narrow ============ -->
      <div class="card-grid">
        <section class="card">
          <div class="card-body">
            <p class="card-title">Permissions (badges, narrow table)</p>
            <div class="table-wrap narrow">
              <table class="table">
                <thead><tr><th>User</th><th>Permission</th><th class="actions"></th></tr></thead>
                <tbody>
                  <tr><td><b>alice</b></td><td><span class="badge badge-accent">WRITE</span></td>
                    <td class="actions"><a class="icon-action danger" href="#"><i class="fa-solid fa-trash"></i></a></td></tr>
                  <tr><td><b>bob</b></td><td><span class="badge">READ</span></td>
                    <td class="actions"><a class="icon-action danger" href="#"><i class="fa-solid fa-trash"></i></a></td></tr>
                  <tr><td><b>Public Read</b></td><td><span class="badge badge-success">true</span></td>
                    <td class="actions"><a class="icon-action" href="#" title="Toggle"><i class="fa-solid fa-arrows-spin"></i></a></td></tr>
                </tbody>
              </table>
            </div>
          </div>
        </section>

        <section class="card">
          <div class="card-body">
            <p class="card-title">Empty State (GroupControl)</p>
            <div class="table-wrap">
              <table class="table">
                <thead><tr><th>User</th><th>Group</th><th class="actions">Delete</th></tr></thead>
                <tbody>
                  <tr><td colspan="3">
                    <div class="empty-state">
                      <i class="fa-solid fa-users"></i>
                      <div>No group records found.</div>
                      <small>Click New Record to add your first group.</small>
                    </div>
                  </td></tr>
                </tbody>
              </table>
            </div>
          </div>
        </section>
      </div>

      <!-- ============ Compact schema table ============ -->
      <section class="card">
        <div class="card-body">
          <p class="card-title">Compact Table (SchemaViewer)</p>
          <div class="table-wrap">
            <table class="table table-compact">
              <thead><tr><th>Table</th><th>Column</th><th>Type</th><th>Key</th></tr></thead>
              <tbody>
                <tr><td>day_plan</td><td><code>id</code></td><td>INTEGER</td><td><span class="badge badge-warning">PK</span></td></tr>
                <tr><td>day_plan</td><td><code>day_code</code></td><td>VARCHAR(10)</td><td></td></tr>
                <tr><td>day_plan</td><td><code>priority</code></td><td>INTEGER</td><td></td></tr>
                <tr><td>day_plan</td><td><code>short_desc</code></td><td>VARCHAR(100)</td><td></td></tr>
              </tbody>
            </table>
          </div>
        </div>
      </section>

      <!-- ============ Key/value + code ============ -->
      <div class="card-grid">
        <section class="card">
          <div class="card-body">
            <p class="card-title">Account Settings (key/value)</p>
            <dl class="kv-list">
              <dt>User</dt><dd>demouser</dd>
              <dt>Email</dt><dd>demouser@example.com</dd>
              <dt>Widgets</dt><dd>3</dd>
            </dl>
            <div class="btn-row">
              <button class="btn">Add Email</button>
              <button class="btn btn-danger">Delete Account</button>
            </div>
          </div>
        </section>

        <section class="card">
          <div class="card-body">
            <p class="card-title">Code Output (TemplateGenerator)</p>
            <p>Inline code looks like <code>W.lookupItem("day_plan", 5)</code>.</p>
<pre><code>const items = W.getItemList("day_plan");
items.forEach(item =&gt; {
    console.log(item.getShortDesc());
});</code></pre>
          </div>
        </section>
      </div>

    </main>
  </div>

</body>
</html>
