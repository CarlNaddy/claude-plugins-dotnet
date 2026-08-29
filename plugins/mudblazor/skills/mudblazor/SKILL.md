---
name: mudblazor
description: >-
  Build, configure, and debug MudBlazor UI in this Blazor Web App. Use when adding or
  editing MudBlazor components (MudDataGrid, MudTable, MudForm, MudDialog, MudAutocomplete,
  MudSelect, layout with MudLayout/MudAppBar/MudDrawer), wiring MudBlazor services and
  providers, theming and dark mode, fixing MudBlazor render-mode, popover, or
  prerendering issues, or authoring this project's own components that wrap or compose
  MudBlazor primitives. Not for generic Blazor component architecture, lifecycle, or
  state coordination — use the dotnet-blazor:* skills for those.
---

# MudBlazor in this project

MudBlazor is the **only** UI toolkit here. There is no upstream Claude skill for it,
so this file is the project's source of truth. It complements — does not replace —
the `dotnet-blazor:*` skills, which still own component architecture, lifecycle,
prerendering, JS interop, and state coordination.

## First, always

1. **Check the installed version** — `grep -i mudblazor **/*.csproj` (or read the
   `.csproj`). MudBlazor's API differs substantially across v6 → v7 → v8; several
   names below changed in v8. Do not trust memory for signatures.
2. **Verify API against the docs for that version** — `https://mudblazor.com/api/<component>`
   and `https://mudblazor.com/components/<component>`. When a build error mentions a
   missing member or changed parameter, check the docs before guessing.
3. The version is **pinned exactly** in the `.csproj` (`Version="8.x.y"`, no `*`). If
   you upgrade it, do it deliberately and skim the MudBlazor migration notes.

## Wiring (must all be present)

| Location | Requirement |
|---|---|
| `.csproj` | `PackageReference Include="MudBlazor" Version="8.x.y"` (exact) |
| `Program.cs` | `builder.Services.AddMudServices();` |
| `_Imports.razor` | `@using MudBlazor` |
| Root component `<head>` | Roboto font link + `_content/MudBlazor/MudBlazor.min.css`; **no** Bootstrap link |
| Before `</body>` | `<script src="_content/MudBlazor/MudBlazor.min.js"></script>` **after** `blazor.web.js` |
| `MainLayout.razor` | `<MudThemeProvider>`, `<MudPopoverProvider>`, `<MudDialogProvider>`, `<MudSnackbarProvider>` |

If popovers/menus/`MudSelect`/tooltips render in the wrong place or not at all,
`MudPopoverProvider` is missing or the layout is running in static SSR.

Copy-paste snippets for every item above, plus forms, dialogs, data grids,
snackbars, and dark mode, are in **`references/patterns.md`** — read it before
writing new MudBlazor code.

## Render mode

- MudBlazor components need an **interactive** render mode (Server or Auto) to
  handle events, popovers, dialogs, and snackbars. Static SSR renders markup but
  nothing is interactive.
- The four providers in `MainLayout` inherit the layout's render mode. If the app
  uses per-page interactivity, the layout itself must be interactive or the
  providers do nothing.
- Prerendering double-runs `OnInitializedAsync`; for MudBlazor data loads follow
  `dotnet-blazor:support-prerendering` (persist state or gate the load).

## Choosing components

| Need | Use | Notes |
|---|---|---|
| Model-bound form + validation | `EditForm` + `DataAnnotationsValidator` + Mud inputs | Simplest; validation attributes on the model. `For="@(() => model.X)"` on each input. |
| Dynamic / standalone validation | `MudForm` + `@ref` + `form.Validate()` | Per-field `Validation` func or list; no `EditContext`. Don't nest in `EditForm`. |
| Tabular data, client-side | `MudDataGrid<T>` with `<PropertyColumn>` / `<TemplateColumn>` | Preferred over `MudTable` for new code. |
| Tabular data, server paging/sort/filter | `MudDataGrid<T>` `ServerData="LoadAsync"` → `GridData<T>` | Do filtering/sorting in the query, not in memory. |
| Modal | `IDialogService.ShowAsync<TDialog>(title, parameters, options)` | Never build a custom overlay. Dialog reads `[CascadingParameter] IMudDialogInstance MudDialog` (v8 name). |
| Toast / notification | `ISnackbar.Add("msg", Severity.Success)` | Configure defaults in `AddMudServices`. |
| App shell | `MudLayout` > `MudAppBar` + `MudDrawer` + `MudMainContent` | Drawer open state is a bound bool in the layout. |
| Icon | `Icons.Material.Filled.X` (also `.Outlined`, `.Rounded`) | `@using MudBlazor` covers it. |

## Styling rules

- Layout and spacing use MudBlazor's utility classes on `Class=` — `pa-4`, `ma-2`,
  `d-flex`, `flex-grow-1`, `gap-2`, `mud-width-full`. These mirror the spacing
  scale, not Bootstrap.
- Component-specific tweaks go in a collocated `.razor.css` (CSS isolation), not a
  global stylesheet.
- No Bootstrap, Tailwind, or hand-rolled grid system. If you catch a `container`,
  `row`, `col-*`, or `btn btn-primary` class, it's leftover template markup —
  replace it with the MudBlazor equivalent.

## v8 gotchas (things model knowledge often gets wrong)

- `MudDialogInstance` → **`IMudDialogInstance`** as the cascading parameter type.
- `DialogService.Show(...)` → prefer **`ShowAsync(...)`**; it returns
  `Task<IDialogReference>`.
- `MudSelect<T>`, `MudAutocomplete<T>` require the `T` type parameter explicitly
  when it can't be inferred.
- Inputs bind with `@bind-Value` (not `@bind-Text`, except `MudTextField` where
  `Text` is the raw string and `Value` is the converted value).
- Dark mode: `<MudThemeProvider @ref="_provider" @bind-IsDarkMode="_isDark" />`;
  read the OS preference with `await _provider.GetSystemPreference()` in
  `OnAfterRenderAsync(firstRender)`.

## Types & namespaces

- Components and most enums are in `MudBlazor`. Many support types — event args
  (`FormFieldChangedEventArgs`), `CssBuilder`, converters, `ParameterState`
  helpers — live in **`MudBlazor.Utilities`**. A `CS0246` on a MudBlazor type
  usually means that `@using` / `using MudBlazor.Utilities;` is missing, not that
  the type is gone.

## Testing MudBlazor components (bUnit)

When testing your own components that use MudBlazor:

- Register a `MudPopoverProvider` (and `MudDialogProvider` for dialogs) in the
  test render tree, or menu/select/tooltip/autocomplete content never renders.
- Never cache `Find()` / `FindAll()` results — re-query after every interaction.
- Drive parameter changes and method calls through `InvokeAsync(...)`.
- Prefer async interactions: `ClickAsync`, `ChangeAsync`, `InputAsync`, `BlurAsync`.
- Register/replace services **before** the first render.
- For time-based behavior, register fake time (`Context.AddFakeTimeProvider()`)
  before rendering; advance it explicitly. No `Task.Delay`, `Thread.Sleep`, or
  polling waits — use `WaitForAssertion` / `WaitForState` only to observe renders.
- Assert semantically (roles, text, classes, `aria-*`, state), not whole-markup
  equality.

## Accessibility

- Verify against the matching **W3C ARIA Authoring Practices Guide** pattern
  (`https://www.w3.org/WAI/ARIA/apg/patterns/`) — its role / name / state /
  keyboard tables are the checklist.
- Check the browser's accessibility tree, not a screen reader. Dynamic state is
  where bugs hide: `aria-expanded` must flip, `aria-activedescendant` must track
  the visual highlight, `aria-selected` must follow selection. A highlight that is
  only a CSS class is invisible to assistive tech.
- Every interactive control needs an accessible name (label, `aria-label`, or
  `aria-labelledby`).

## Authoring the project's own components

When building components **this app owns** that wrap or compose MudBlazor
(e.g. `<MoneyField>`, a themed `<AppDataGrid>`), read
**`references/authoring-components.md`** and use `dotnet-blazor:author-component`
for the generic Blazor mechanics. Core rules:

- Don't re-implement what MudBlazor ships. Build one only for domain/composite
  needs or to pin project defaults on a Mud component.
- Inherit `ComponentBase`; inherit `MudComponentBase` only for Mud-style
  primitives that want `Class`/`Style`/`@attributes` passthrough for free.
- Auto-property parameters only; forward `Class`/`Style`/`@attributes`; build
  class strings with `CssBuilder`; theme tokens, never hard-coded colors;
  positive boolean names; CSS in a collocated `.razor.css`.
- Accessible name on every interactive control; generated `aria-*` as overridable
  fallbacks; `[CascadingParameter] bool RightToLeft` when layout is directional.

## Definition of done for a MudBlazor change

- `dotnet build` clean (MudBlazor analyzer warnings addressed, not suppressed).
- Runs under the app's real render mode, not just prerender.
- No Bootstrap/foreign CSS classes introduced.
- Component API used matches the pinned version's docs.

## Provenance

The bUnit, accessibility, styling, namespace, and component-authoring guidance in
this skill is the **app-development subset** of MudBlazor's own contributor guide
(`github.com/MudBlazor/MudBlazor` → `AGENTS.md` on `dev`, distilled 2026-08-29).
Everything about that guide's build system — `SkipBunCompile`, docs-project
builds, analyzer tests, viewer components, restore rules, the `dotnet format`
charset pass — is for contributors to the library itself and is intentionally
excluded. There is no live link; re-read `AGENTS.md` upstream to refresh.
