using EventStore.Serialization.ServiceStack;

namespace EventStore.Serialization.AcceptanceTests
{
    public partial class SerializerFixture
    {
        public SerializerFixture()
        {
            createSerializer = () =>
                new ServiceStackSerializer();
        }
    }
}