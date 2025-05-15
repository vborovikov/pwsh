namespace $rootnamespace$;

using System;
using System.Buffers.Text;
using System.ComponentModel;
using System.Diagnostics.CodeAnalysis;
using System.Globalization;
using System.Numerics;
using System.Text.Json;
using System.Text.Json.Serialization;
using Identity = System.Guid;

/// <summary>
/// Represents an unique identifier for an object.
/// </summary>
/// <remarks>
/// The <see cref="$safeitemname$"/> type is used to uniquely identify objects within the system.
/// </remarks>
[TypeConverter(typeof($safeitemname$TypeConverter)), JsonConverter(typeof($safeitemname$JsonConverter))]
public readonly struct $safeitemname$ : IEquatable<$safeitemname$>, IComparable, IComparable<$safeitemname$>,
    ISpanFormattable, IUtf8SpanFormattable, ISpanParsable<$safeitemname$>, IUtf8SpanParsable<$safeitemname$>,
    IEqualityOperators<$safeitemname$, $safeitemname$, bool>, IComparisonOperators<$safeitemname$, $safeitemname$, bool>
{
    private readonly Identity identity;

    private $safeitemname$(Identity value)
    {
        this.identity = value;
    }

    /// <inheritdoc />
    public override int GetHashCode() => this.identity.GetHashCode();

    /// <inheritdoc />
    public override string ToString() => this.identity.ToString("D", CultureInfo.InvariantCulture);

    /// <inheritdoc />
    public override bool Equals([NotNullWhen(true)] object? obj) => obj is $safeitemname$ id && Equals(id);

    /// <inheritdoc />
    public bool Equals($safeitemname$ other) => this.identity.Equals(other.identity);

    /// <inheritdoc />
    public int CompareTo(object? obj)
    {
        if (obj is null)
            return 1;
        if (obj is not $safeitemname$ other)
            throw new ArgumentException($"Object must be of type {nameof($safeitemname$)}.", nameof(obj));

        return CompareTo(other);
    }

    /// <inheritdoc />
    public int CompareTo($safeitemname$ other) => this.identity.CompareTo(other.identity);

    /// <inheritdoc />
    public string ToString(string? format, IFormatProvider? formatProvider) => this.identity.ToString(format, formatProvider);

    /// <inheritdoc />
    public bool TryFormat(Span<char> destination, out int charsWritten, ReadOnlySpan<char> format, IFormatProvider? provider) =>
        this.identity.TryFormat(destination, out charsWritten, format);

    /// <inheritdoc />
    public bool TryFormat(Span<byte> utf8Destination, out int bytesWritten, ReadOnlySpan<char> format, IFormatProvider? provider) =>
        this.identity.TryFormat(utf8Destination, out bytesWritten, format);

    /// <summary>
    /// Creates a new instance of the <see cref="$safeitemname$"/> type.
    /// </summary>
    /// <returns>A new instance of the <see cref="$safeitemname$"/> type.</returns>
    public static $safeitemname$ New$safeitemname$() => new(Identity.NewGuid());

    /// <inheritdoc cref="Parse(ReadOnlySpan{char}, IFormatProvider?)" />
    public static $safeitemname$ Parse(ReadOnlySpan<char> s) => Parse(s, CultureInfo.InvariantCulture);

    /// <inheritdoc cref="TryParse(ReadOnlySpan{char}, IFormatProvider?, out $safeitemname$)" />
    public static bool TryParse(ReadOnlySpan<char> s, [MaybeNullWhen(false)] out $safeitemname$ result) => TryParse(s, CultureInfo.InvariantCulture, out result);

    /// <inheritdoc cref="Parse(string, IFormatProvider?)" />
    public static $safeitemname$ Parse(string s) => Parse(s, CultureInfo.InvariantCulture);

    /// <inheritdoc cref="TryParse(string, IFormatProvider?, out $safeitemname$)" />
    public static bool TryParse(string s, [MaybeNullWhen(false)] out $safeitemname$ result) => TryParse(s, CultureInfo.InvariantCulture, out result);

    /// <inheritdoc cref="Parse(ReadOnlySpan{byte}, IFormatProvider?)" />
    public static $safeitemname$ Parse(ReadOnlySpan<byte> utf8Text) => Parse(utf8Text, CultureInfo.InvariantCulture);

    /// <inheritdoc cref="TryParse(ReadOnlySpan{byte}, IFormatProvider?, out $safeitemname$)" />
    public static bool TryParse(ReadOnlySpan<byte> utf8Text, [MaybeNullWhen(false)] out $safeitemname$ result) => TryParse(utf8Text, CultureInfo.InvariantCulture, out result);

    /// <inheritdoc />
    public static $safeitemname$ Parse(ReadOnlySpan<char> s, IFormatProvider? provider) =>
        TryParse(s, provider, out var id) ? id : throw new FormatException();

    /// <inheritdoc />
    public static bool TryParse(ReadOnlySpan<char> s, IFormatProvider? provider, [MaybeNullWhen(false)] out $safeitemname$ result)
    {
        if (Identity.TryParse(s, provider, out var value))
        {
            result = new(value);
            return true;
        }

        result = default;
        return false;
    }

    /// <inheritdoc />
    public static $safeitemname$ Parse(string s, IFormatProvider? provider) =>
        Parse(s.AsSpan(), provider);

    /// <inheritdoc />
    public static bool TryParse([NotNullWhen(true)] string? s, IFormatProvider? provider, [MaybeNullWhen(false)] out $safeitemname$ result) =>
        TryParse(s.AsSpan(), provider, out result);

    /// <inheritdoc />
    public static $safeitemname$ Parse(ReadOnlySpan<byte> utf8Text, IFormatProvider? provider) =>
        TryParse(utf8Text, provider, out var id) ? id : throw new FormatException();

    /// <inheritdoc />
    public static bool TryParse(ReadOnlySpan<byte> utf8Text, IFormatProvider? provider, [MaybeNullWhen(false)] out $safeitemname$ result)
    {
        if (Utf8Parser.TryParse(utf8Text, out Identity value, out _))
        {
            result = new(value);
            return true;
        }

        result = default;
        return false;
    }

    /// <inheritdoc />
    public static bool operator ==($safeitemname$ left, $safeitemname$ right) => left.Equals(right);

    /// <inheritdoc />
    public static bool operator !=($safeitemname$ left, $safeitemname$ right) => !(left == right);

    /// <inheritdoc />
    public static bool operator >($safeitemname$ left, $safeitemname$ right) => left.CompareTo(right) > 0;

    /// <inheritdoc />
    public static bool operator <($safeitemname$ left, $safeitemname$ right) => left.CompareTo(right) < 0;

    /// <inheritdoc />
    public static bool operator >=($safeitemname$ left, $safeitemname$ right) => left.CompareTo(right) >= 0;

    /// <inheritdoc />
    public static bool operator <=($safeitemname$ left, $safeitemname$ right) => left.CompareTo(right) <= 0;

    /// <summary>
    /// Implicitly converts the specified <see cref="Identity"/> to a $safeitemname$
    /// </summary>
    /// <param name="id">The <see cref="Identity"/> to convert.</param>
    /// <returns>A new instance of the <see cref="$safeitemname$"/> type.</returns>
    public static implicit operator $safeitemname$(Identity id) => new(id);

    /// <summary>
    /// Explicitly converts the specified <see cref="$safeitemname$"/> to an <see cref="Identity"/>.
    /// </summary>
    /// <param name="id">The <see cref="$safeitemname$"/> to convert.</param>
    /// <returns>The <see cref="Identity"/> that was converted.</returns>
    public static explicit operator Identity($safeitemname$ id) => id.identity;

    /// <summary>
    /// Converts the specified object to a <see cref="$safeitemname$"/>.
    /// </summary>
    /// <param name="value">The object to convert.</param>
    /// <param name="culture">The culture to use in the conversion.</param>
    /// <returns>A <see cref="$safeitemname$"/> that represents the converted object.</returns>
    public static $safeitemname$ ConvertFrom(object value, CultureInfo? culture = null) =>
        value switch
        {
            byte[] span when span.Length == 16 => new $safeitemname$(new Identity(span)),
            byte[] span when span.Length > 16 && Utf8Parser.TryParse(span, out Identity id, out _) => new $safeitemname$(id),
            char[] span when span.Length >= 16 && Identity.TryParse(span, culture, out var id) => new $safeitemname$(id),
            string str when Identity.TryParse(str, culture, out var id) => new $safeitemname$(id),
            Identity id => new $safeitemname$(id),
            not null when Identity.TryParse(value.ToString(), culture, out var id) => new $safeitemname$(id),
            _ => throw new NotSupportedException()
        };

    private sealed class $safeitemname$TypeConverter : TypeConverter
    {
        public override bool CanConvertFrom(ITypeDescriptorContext? context, Type sourceType) =>
            sourceType == typeof(byte[]) || sourceType == typeof(char[]) ||
            sourceType == typeof(string) || sourceType == typeof(Identity);

        public override object ConvertFrom(ITypeDescriptorContext? context, CultureInfo? culture, object value) =>
            $safeitemname$.ConvertFrom(value, culture);
    }

    private sealed class $safeitemname$JsonConverter : JsonConverter<$safeitemname$>
    {
        public override $safeitemname$ Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) =>
            new(reader.GetGuid());

        public override void Write(Utf8JsonWriter writer, $safeitemname$ value, JsonSerializerOptions options) =>
            writer.WriteStringValue(value.identity);
    }
}