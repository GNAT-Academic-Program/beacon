---
name: writing-style
description: Use before writing or changing text in this repository, such as README.md, ARCHITECTURE.md, CONTRIBUTING.md, Ada comments, commit messages, and issue or pull request text. Applies controlled technical English (ASD-STE100-inspired) and the Beacon comment and commit rules.
---

# Writing style

Use this skill when you write or change text that people read: Markdown
documentation, Ada comments, commit messages, and issue or pull request text.

## Controlled English

These rules come from ASD-STE100 (Simplified Technical English). They are
writing principles. They do not replace the official ASD-STE100 specification
or dictionary, and this file does not include the dictionary.

- Put one main idea in each sentence.
- Use an explicit subject and an active verb.
- Use one term for one concept.
- Define unfamiliar terms before using them.
- Use `must`, `should`, and `may` for requirements and choices.
- State conditions, actions, and expected results explicitly.
- Prefer short, familiar words and concrete nouns.
- Avoid idioms, jokes, vague qualifiers, ambiguous pronouns, and unnecessary
  passive voice.
- State assumptions, unknowns, and failure conditions.
- Write an instruction as a command ("Run the tests."). Put a sequence of
  steps in a numbered list, with one action in each step.
- Keep an instruction to 20 words or fewer and a description to 25 words or
  fewer. Keep a paragraph to 6 sentences or fewer.

Preserve the author's meaning when a style rule and the requested content
conflict.

## Beacon rules

`CONTRIBUTING.md` § Style is the source for code style. These rules add to it.

- Use the names that the README and the Ada specs use. Do not add a synonym
  for a concept that already has a name.
- Refer to a design rule by its number in README § Design rules, in the form
  `Design rule 3: ...`.
- When you rewrite a comment, keep its meaning. If a comment and its contract
  disagree, tell the user. Do not change one of them to agree with the other.

### Ada comments

- Write `--` and two spaces, then the text. Keep each line to 100 columns or
  fewer. The build checks both (`-gnatyg`, `-gnatyM100`).
- Put the comment for a subprogram directly above its declaration, at the
  same indentation, with no empty line between them. This is the form in
  `src/*.ads`. GNATdoc calls it the `leading` style.
- In a spec, state what the subprogram guarantees and what the caller must
  do. Do not state how the body works.
- In a body, state why the code does something, not what the next line does.

### Commit messages

- Use the Conventional Commits form: `type(scope): summary`. Use the types
  `feat`, `fix`, `docs`, `test`, `refactor`, and `chore`.
- Write the summary as one line in the imperative mood.
- Add a body when the summary is not sufficient. The body states why the
  change is necessary.
- Refer to the issue in the body, for example `Refs #12` or `Closes #12`.

## Check before you finish

1. Read each new sentence. Make sure that it has a subject and an active verb.
2. Make sure that each concept has one term in the text that you changed.
3. If you changed an Ada file, run `alr -n build`. Make sure that the style
   checks pass.
