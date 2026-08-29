# MudBlazor patterns (copy-paste starting points)

Adjust to the pinned MudBlazor version. Verify any changed member against
`https://mudblazor.com/api/<component>`.

---

## 1. Wiring

### `Program.cs`

```csharp
using MudBlazor.Services;

builder.Services.AddMudServices(config =>
{
    config.SnackbarConfiguration.PositionClass = Defaults.Classes.Position.BottomRight;
    config.SnackbarConfiguration.PreventDuplicates = true;
    config.SnackbarConfiguration.NewestOnTop = true;
    config.SnackbarConfiguration.VisibleStateDuration = 4000;
});
```

### Root component `<head>` (e.g. `Components/App.razor`)

```html
<link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Roboto:300,400,500,700&display=swap" />
<link rel="stylesheet" href="_content/MudBlazor/MudBlazor.min.css" />
<!-- remove: <link rel="stylesheet" href="bootstrap/bootstrap.min.css" /> -->
```

### Before `</body>`, after the Blazor script

```html
<script src="_framework/blazor.web.js"></script>
<script src="_content/MudBlazor/MudBlazor.min.js"></script>
```

### `_Imports.razor`

```razor
@using MudBlazor
```

---

## 2. `MainLayout.razor`

```razor
@inherits LayoutComponentBase

<MudThemeProvider @ref="_themeProvider" @bind-IsDarkMode="_isDarkMode" Theme="_theme" />
<MudPopoverProvider />
<MudDialogProvider />
<MudSnackbarProvider />

<MudLayout>
    <MudAppBar Elevation="1">
        <MudIconButton Icon="@Icons.Material.Filled.Menu" Color="Color.Inherit" Edge="Edge.Start"
                       OnClick="@(() => _drawerOpen = !_drawerOpen)" />
        <MudText Typo="Typo.h6">dotnetskills</MudText>
        <MudSpacer />
        <MudIconButton Icon="@(_isDarkMode ? Icons.Material.Filled.LightMode : Icons.Material.Filled.DarkMode)"
                       Color="Color.Inherit" OnClick="@(() => _isDarkMode = !_isDarkMode)" />
    </MudAppBar>

    <MudDrawer @bind-Open="_drawerOpen" Elevation="2" ClipMode="DrawerClipMode.Always">
        <NavMenu />
    </MudDrawer>

    <MudMainContent Class="pa-4">
        @Body
    </MudMainContent>
</MudLayout>

@code {
    private MudThemeProvider _themeProvider = null!;
    private bool _drawerOpen = true;
    private bool _isDarkMode;
    private readonly MudTheme _theme = new();

    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
        {
            _isDarkMode = await _themeProvider.GetSystemPreference();
            StateHasChanged();
        }
    }
}
```

---

## 3. Form — `EditForm` + DataAnnotations (default choice)

```razor
<EditForm Model="_model" OnValidSubmit="SubmitAsync">
    <DataAnnotationsValidator />
    <MudStack Spacing="3">
        <MudTextField @bind-Value="_model.Name" Label="Name"
                      For="@(() => _model.Name)" Immediate="true" />
        <MudSelect T="string" @bind-Value="_model.Country" Label="Country"
                   For="@(() => _model.Country)">
            @foreach (var c in _countries)
            {
                <MudSelectItem Value="c">@c</MudSelectItem>
            }
        </MudSelect>
        <MudButton ButtonType="ButtonType.Submit" Variant="Variant.Filled" Color="Color.Primary">
            Save
        </MudButton>
    </MudStack>
</EditForm>

@code {
    private sealed class FormModel
    {
        [Required, StringLength(80)] public string Name { get; set; } = "";
        [Required] public string Country { get; set; } = "";
    }

    private readonly FormModel _model = new();
    private readonly string[] _countries = ["Germany", "Austria", "Switzerland"];

    private async Task SubmitAsync()
    {
        // persist _model
        await Task.CompletedTask;
    }
}
```

## 3b. Form — `MudForm` (dynamic / no EditContext)

```razor
<MudForm @ref="_form" @bind-IsValid="_isValid">
    <MudTextField T="string" @bind-Value="_name" Label="Name" Required="true"
                  Validation="@(new Func<string, string?>(ValidateName))" />
    <MudButton OnClick="SubmitAsync" Disabled="@(!_isValid)" Variant="Variant.Filled">Save</MudButton>
</MudForm>

@code {
    private MudForm _form = null!;
    private bool _isValid;
    private string _name = "";

    private static string? ValidateName(string v) =>
        string.IsNullOrWhiteSpace(v) ? "Name is required" : v.Length > 80 ? "Too long" : null;

    private async Task SubmitAsync()
    {
        await _form.Validate();
        if (_form.IsValid) { /* persist */ }
    }
}
```

---

## 4. `MudDataGrid<T>` — server-side data

```razor
<MudDataGrid T="Customer" ServerData="LoadAsync" SortMode="SortMode.Multiple"
             Filterable="true" @ref="_grid">
    <Columns>
        <PropertyColumn Property="x => x.Name" Title="Name" />
        <PropertyColumn Property="x => x.CreatedUtc" Title="Created" Format="yyyy-MM-dd" />
        <TemplateColumn Title="Actions" Sortable="false" Filterable="false">
            <CellTemplate>
                <MudIconButton Icon="@Icons.Material.Filled.Edit" Size="Size.Small"
                               OnClick="@(() => EditAsync(context.Item))" />
            </CellTemplate>
        </TemplateColumn>
    </Columns>
    <PagerContent>
        <MudDataGridPager T="Customer" />
    </PagerContent>
</MudDataGrid>

@code {
    private MudDataGrid<Customer> _grid = null!;

    private async Task<GridData<Customer>> LoadAsync(GridState<Customer> state)
    {
        var query = _db.Customers.AsQueryable();

        foreach (var sd in state.SortDefinitions)
            query = sd.Descending
                ? query.OrderByDescending(BuildKeySelector(sd.SortBy))
                : query.OrderBy(BuildKeySelector(sd.SortBy));

        var total = await query.CountAsync();
        var items = await query
            .Skip(state.Page * state.PageSize)
            .Take(state.PageSize)
            .ToListAsync();

        return new GridData<Customer> { TotalItems = total, Items = items };
    }
}
```

For small in-memory sets, drop `ServerData` and pass `Items="@_list"` instead.

---

## 5. Dialog

### Host call

```razor
@inject IDialogService DialogService

@code {
    private async Task EditAsync(Customer c)
    {
        var parameters = new DialogParameters<CustomerDialog> { { x => x.Customer, c } };
        var options = new DialogOptions { CloseButton = true, MaxWidth = MaxWidth.Small, FullWidth = true };

        var dialog = await DialogService.ShowAsync<CustomerDialog>("Edit customer", parameters, options);
        var result = await dialog.Result;

        if (result is not null && !result.Canceled)
            await _grid.ReloadServerData();
    }
}
```

### `CustomerDialog.razor`

```razor
<MudDialog>
    <DialogContent>
        <MudTextField @bind-Value="Customer.Name" Label="Name" />
    </DialogContent>
    <DialogActions>
        <MudButton OnClick="Cancel">Cancel</MudButton>
        <MudButton Color="Color.Primary" OnClick="Submit">Save</MudButton>
    </DialogActions>
</MudDialog>

@code {
    [CascadingParameter] private IMudDialogInstance MudDialog { get; set; } = null!;
    [Parameter] public Customer Customer { get; set; } = null!;

    private void Cancel() => MudDialog.Cancel();
    private void Submit() => MudDialog.Close(DialogResult.Ok(Customer));
}
```

---

## 6. Snackbar

```razor
@inject ISnackbar Snackbar

@code {
    private void Saved() => Snackbar.Add("Customer saved", Severity.Success);
    private void Failed(string why) => Snackbar.Add(why, Severity.Error);
}
```

---

## 7. Custom theme

```csharp
public static class AppTheme
{
    public static readonly MudTheme Instance = new()
    {
        PaletteLight = new PaletteLight
        {
            Primary = "#1867c0",
            AppbarBackground = "#1867c0",
        },
        PaletteDark = new PaletteDark
        {
            Primary = "#7986cb",
        },
        LayoutProperties = new LayoutProperties
        {
            DefaultBorderRadius = "8px",
        },
    };
}
```

Pass to the provider: `<MudThemeProvider Theme="AppTheme.Instance" ... />`.

---

## Pitfalls

- **Nothing is clickable** → layout/page is static SSR; give it an interactive render mode.
- **Menu/select opens at page top-left or not at all** → `MudPopoverProvider` missing.
- **Dialog/snackbar does nothing** → provider missing, or provider is in a non-interactive layout.
- **Styles look unstyled** → `MudBlazor.min.css` not referenced, or Bootstrap CSS still loaded and conflicting.
- **`MudBlazor.min.js` 404 / JS errors** → script tag missing or placed before `blazor.web.js`.
- **Grid re-queries the whole table each keystroke** → debounce filters; do paging/sort/filter in the DB query inside `ServerData`.
- **Build error on a member that "should exist"** → version mismatch; check the pinned version's API page.
