using System.IO;
using ServiceStack.Text;

namespace EventStore.Serialization.ServiceStack
{
    public class ServiceStackSerializer : ISerialize
    {
        public void Serialize<T>(Stream output, T graph)
        {
            using (var jsConfigScope = JsConfig.BeginScope())
            {
                //jsConfigScope.TryToParsePrimitiveTypeValues = true;
                JsonSerializer.SerializeToStream(graph, output);
            }
        }

        public T Deserialize<T>(Stream input)
        {
            using (var jsConfigScope = JsConfig.BeginScope())
            {
               // jsConfigScope.TryToParsePrimitiveTypeValues = true;
                return JsonSerializer.DeserializeFromStream<T>(input);
            }
        }
    }
}
