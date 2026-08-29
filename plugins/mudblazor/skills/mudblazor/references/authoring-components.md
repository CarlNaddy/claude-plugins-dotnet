# Authoring the project's own components on top of MudBlazor

For components **this app owns** that wrap or compose MudBlazor primitives —
e.g. `<MoneyField>`, `<CustomerPicker>`, a themed `<AppDataGrid>`. Not for
contributing to the MudBlazor library.

Generic Blazor mechanics (lifecycle, `EventCallback`, `RenderFragment`,
`IAsyncDisposable`, `CancellationToken`, CSS isolation) are owned by
**`dotnet-blazor:author-component`** — use it alongside this file. The rules
below are the MudBlazor-flavored conventions layered on top, distilled from
MudBlazor's own contributor guide and kept only where they apply to a consumer.

## When to build one

- A **domain/composite** component that bundles several Mud components plus app
  logic and is used in more than one place.
- A **themed wrapper** that pins project defaults on a Mud component (variant,
  margin, density) so call sites stay consistent.
- Do **not** re-implement something MudBlazor already ships. Check the component
  list first.

## Base class

- Default: inherit `ComponentBase`. Compose MudBlazor components in the markup.
- Inherit `MudBlazor.MudComponentBase` only when the component is effectively a
  Mud-style primitive and you want its `Class`, `Style`, and `UserAttributes`
  (`@attributes`) passthrough for free. It also unlocks MudBlazor's parameter
  registration API (below).

## Parameters and state

- Public parameters are **auto-properties only** — no logic in getters/setters.
- Two-way binding: expose `Value` / `ValueChanged` / `ValueExpression`; update
  through the callback, never mutate the incoming parameter.
- Reaction to a changed parameter goes in `OnParametersSetAsync` (diff against a
  cached previous value) or a change handler — not in a setter.
- Do not set another component's parameters via `@ref` (analyzer `BL0005`);
  bind declaratively.
- **Optional** — only if you inherited `MudComponentBase` and want MudBlazor's
  parameter-state framework instead of manual diffing:

  ```csharp
  private readonly ParameterState<bool> _denseState;

  [Parameter] public bool Dense { get; set; }
  [Parameter] public EventCallback<bool> DenseChanged { get; set; }

  public AppThing()
  {
      using var scope = CreateRegisterScope();
      _denseState = scope.RegisterParameter<bool>(nameof(Dense))
          .WithParameter(() => Dense)
          .WithEventCallback(() => DenseChanged)
          .WithChangeHandler(OnDenseChangedAsync);
  }
  ```

  `ParameterState<T>` is in `MudBlazor.State`. Standard Blazor patterns are
  perfectly fine; reach for this only when you want change-handler plumbing that
  matches MudBlazor's internals.

## Styling and naming

- Build class strings with `MudBlazor.Utilities.CssBuilder`, style strings with
  `StyleBuilder`:

  ```csharp
  protected string RootClass => new CssBuilder("app-money-field")
      .AddClass("app-money-field--dense", Dense)
      .AddClass(Class)                       // caller override wins
      .Build();
  ```

- Always forward `Class`, `Style`, and `@attributes` so callers can override.
- Use CSS custom properties / MudBlazor theme tokens
  (`var(--mud-palette-primary)`, `var(--mud-typography-body1-size)`, …).
  **Never hard-code colors.** Component-specific CSS goes in a collocated
  `.razor.css` (CSS isolation), not a global sheet.
- Prefer **positive** boolean parameter names — `Gutters`, not `DisableGutters`.
  The default value should be the common case.
- No `#region`.
- A helper used by one method is a `static` local function inside it; promote to
  a private member only when shared.

## Accessibility

- Every interactive control needs an accessible name — a visible label,
  `aria-label`, or `aria-labelledby`.
- Emit `role` / `aria-*` you generate as **fallbacks** so caller-supplied
  `@attributes` can override them; don't hard-force unless behavior requires it.
- Keyboard navigation must work for anything interactive.
- Add `[CascadingParameter] public bool RightToLeft { get; set; }` when layout
  depends on direction (this matches MudBlazor's RTL cascade).
- Verify against the matching W3C ARIA APG pattern
  (`https://www.w3.org/WAI/ARIA/apg/patterns/`); check the browser accessibility
  tree, not a screen reader. Dynamic state matters most: `aria-expanded`,
  `aria-activedescendant`, `aria-selected` must track the visual state.

## XML docs (recommended for shared components)

- `<summary>` on each public parameter describing **behavior**, not
  "Gets or sets…".
- `<remarks>` noting the default when it isn't obvious.
- Skip MudBlazor's `[Category(CategoryTypes...)]` attribute — that only feeds
  MudBlazor's own API browser and is meaningless in this app.

## Testing

Follow the bUnit rules in `SKILL.md` (§ Testing MudBlazor components):
register the needed Mud providers, fail-first, re-query after interactions,
fake time before render, semantic assertions. Reference a real APG-conformant
component's test for interactive a11y assertions.

## Definition of done

- Builds clean; no new analyzer warnings.
- `Class` / `Style` / `@attributes` passthrough works.
- No hard-coded colors; component CSS is isolated.
- Accessible name present; APG pattern checklist passes for interactive components.
- bUnit test covers the behavior, with the right providers registered.
