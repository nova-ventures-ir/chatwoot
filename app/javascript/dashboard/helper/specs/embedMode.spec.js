import { frontendURL } from '../URLHelper';
import {
  embedAccountId,
  enforceEmbedRoute,
  isEmbedMode,
  rememberEmbedMode,
} from '../embedMode';

describe('embedMode', () => {
  afterEach(() => {
    sessionStorage.clear();
  });

  it('remembers embed mode and the locked account', () => {
    rememberEmbedMode({ query: { embed: '1' }, params: { accountId: '42' } });

    expect(isEmbedMode()).toBe(true);
    expect(embedAccountId()).toBe('42');
  });

  it('sends account switches and account creation back to the locked inbox', () => {
    rememberEmbedMode({ query: { embed: '1' }, params: { accountId: '42' } });
    const next = vi.fn();

    const blocked = enforceEmbedRoute(
      { name: 'home', params: { accountId: '7' }, query: {} },
      next
    );

    expect(blocked).toBe(true);
    expect(next).toHaveBeenCalledWith({
      path: frontendURL('accounts/42/conversations'),
      query: { embed: '1' },
    });
  });

  it('blocks the create-account route', () => {
    rememberEmbedMode({ query: { embed: '1' }, params: { accountId: '42' } });
    const next = vi.fn();

    expect(
      enforceEmbedRoute(
        {
          name: 'onboarding_account_details',
          params: { accountId: '42' },
          query: {},
        },
        next
      )
    ).toBe(true);
  });

  it('leaves the locked account inbox alone', () => {
    rememberEmbedMode({ query: { embed: '1' }, params: { accountId: '42' } });
    const next = vi.fn();

    expect(
      enforceEmbedRoute(
        { name: 'home', params: { accountId: '42' }, query: { embed: '1' } },
        next
      )
    ).toBe(false);
    expect(next).not.toHaveBeenCalled();
  });
});
