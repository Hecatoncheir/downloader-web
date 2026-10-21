"""Версионирует загрузчик и Dart JS, сохраняя исходные файлы для Flutter worker."""
from hashlib import sha256
from pathlib import Path


def fingerprint(path: Path) -> str:
    digest = sha256(path.read_bytes()).hexdigest()[:16]
    versioned = path.with_name(f'{path.stem}.{digest}{path.suffix}')
    versioned.write_bytes(path.read_bytes())
    return versioned.name


def prepare(root: Path) -> None:
    main = fingerprint(root / 'main.dart.js')
    bootstrap = root / 'flutter_bootstrap.js'
    source = bootstrap.read_text(encoding='utf-8')
    marker = '"mainJsPath":"main.dart.js"'
    if marker not in source:
        raise ValueError('В загрузчике Flutter не найден mainJsPath')
    bootstrap.write_text(source.replace(marker, f'"mainJsPath":"{main}"'), encoding='utf-8')
    loader = fingerprint(bootstrap)
    index = root / 'index.html'
    source = index.read_text(encoding='utf-8')
    marker = 'src="flutter_bootstrap.js"'
    if marker not in source:
        raise ValueError('В index.html не найден загрузчик Flutter')
    index.write_text(source.replace(marker, f'src="{loader}"'), encoding='utf-8')
    print(f'Загрузчик: {loader}; приложение: {main}')


if __name__ == '__main__':
    prepare(Path('build/web'))
